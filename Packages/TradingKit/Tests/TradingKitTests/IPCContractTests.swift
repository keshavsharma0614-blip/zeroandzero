import Foundation
import Testing
@testable import TradingKit
@testable import alpaca_agentctl

@Test("IPC router rejects missing token")
func ipcUnauthorizedMissingToken() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(method: "GET", path: "/status", headers: [:], body: Data())
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 401)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "unauthorized")
}

@Test("IPC router rejects wrong token")
func ipcUnauthorizedWrongToken() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/status",
            headers: ["x-agent-token": "wrong-token"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 401)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "unauthorized")
}

@Test("IPC router unknown path returns 404")
func ipcUnknownPath() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/unknown-route",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "not_found")
}

@Test("GET /status returns success envelope")
func ipcStatusRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/status",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["state"] == .string("ok"))
}

@Test("GET /strategies returns success envelope with array")
func ipcStrategiesRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/strategies",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let strategies = envelope.result?.arrayValue ?? []
    #expect(strategies.count == 1)
}

@Test("POST /strategy/start invalid JSON body returns bad_request")
func ipcStrategyStartInvalidBody() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/strategy/start",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /strategy/start strategy_not_found maps to 404")
func ipcStrategyStartNotFound() async throws {
    let handlers = makeContractHandlers(startStrategy: { id, _ in
        throw StrategyRunnerError.strategyNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/strategy/start",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["id": .string("missing")]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "strategy_not_found")
}

@Test("GET /proposal missing id returns bad_request")
func ipcProposalMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/proposal",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /proposal not found returns proposal_not_found")
func ipcProposalNotFound() async throws {
    let handlers = makeContractHandlers(proposal: { _ in nil })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/proposal?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "proposal_not_found")
}

@Test("POST /replay/quick invalid days returns replay_invalid_days")
func ipcReplayQuickInvalidDays() async throws {
    let handlers = makeContractHandlers(replayQuick: { _ in
        throw ReplayError.invalidDays
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let body = try JSONEncoder().encode(
        JSONValue.object([
            "proposalId": .string("proposal-1"),
            "symbols": .array([.string("AAPL")]),
            "timeframe": .string("1Min"),
            "days": .number(0),
            "end": .null,
            "speed": .string("fast"),
            "autoIngest": .bool(true),
            "feed": .string("iex"),
            "simulateTrades": .bool(false),
            "allowTradingInReplay": .bool(false),
            "fillPolicy": .string("next_open_market"),
            "slippageBps": .object([
                "market": .number(0),
                "limit": .number(0)
            ])
        ])
    )
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/replay/quick",
            headers: ["x-agent-token": "token-123"],
            body: body
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "replay_invalid_days")
}

@Test("POST /safety/kill-switch missing enabled returns bad_request")
func ipcKillSwitchBadRequest() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/safety/kill-switch",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([:]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /safety/arm-live requires local Mac app and does not arm through IPC")
func ipcArmLiveRequiresLocalMacAppAndDoesNotCallHandler() async throws {
    let recorder = IPCCallRecorder()
    let handlers = makeContractHandlers(
        status: {
            .object([
                "state": .string("ok"),
                "armed": .bool(false)
            ])
        },
        armLive: {
            await recorder.record()
            return "session-1"
        }
    )
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/safety/arm-live",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    let result = try #require(envelope.result?.objectValue)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(result["armed"] == .bool(false))
    #expect(result["armingSessionId"] == .null)
    #expect(result["blocked"] == .bool(true))
    #expect(result["code"] == .string("local_app_required_for_live_arming"))
    #expect(result["message"]?.stringValue?.contains("Mac app") == true)
    #expect(await recorder.callCount() == 0)

    let statusResponse = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/status",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )
    let statusEnvelope = try decodeEnvelope(statusResponse)
    #expect(statusEnvelope.result?.objectValue?["armed"] == .bool(false))
}

@Test("POST /safety/disarm-live remains available over IPC")
func ipcDisarmLiveStillCallsHandler() async throws {
    let recorder = IPCCallRecorder()
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: makeContractHandlers(disarmLive: {
            await recorder.record()
        })
    )

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/safety/disarm-live",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["armed"] == .bool(false))
    #expect(await recorder.callCount() == 1)
}

@Test("POST /safety/kill-switch remains available over IPC")
func ipcKillSwitchStillCallsHandler() async throws {
    let recorder = IPCBoolRecorder()
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: makeContractHandlers(setKillSwitch: { enabled in
            await recorder.record(enabled)
        })
    )

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/safety/kill-switch",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["enabled": .bool(true)]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["enabled"] == .bool(true))
    #expect(await recorder.values() == [true])
}

@Test("GET /jobs returns success envelope with array")
func ipcJobsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/jobs",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let jobs = envelope.result?.arrayValue ?? []
    #expect(jobs.count == 1)
}

@Test("GET /rss/feeds returns success envelope with array")
func ipcRSSFeedsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/rss/feeds",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let feeds = envelope.result?.arrayValue ?? []
    #expect(feeds.count == 1)
}

@Test("POST /rss/feed/add missing name returns bad_request")
func ipcRSSFeedAddMissingName() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/rss/feed/add",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(
                JSONValue.object([
                    "url": .string("https://example.com/feed.xml")
                ])
            )
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /news returns success envelope with array")
func ipcNewsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/news?limit=10",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let events = envelope.result?.arrayValue ?? []
    #expect(events.count == 1)
}

@Test("GET /news invalid since returns bad_request with ISO8601 guidance")
func ipcNewsRouteInvalidSince() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/news?since=not-a-date",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
    #expect(envelope.error?.message.contains("ISO8601") == true)
}

@Test("GET /pm/profiles returns success envelope with array")
func ipcPMProfilesRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/profiles",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let profiles = envelope.result?.arrayValue ?? []
    #expect(profiles.count == 1)
    #expect(profiles.first?.objectValue?["pmId"] == .string("pm-primary"))
}

@Test("GET /pm/profile missing id returns bad_request")
func ipcPMProfileMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/profile",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/profile not found returns pm_profile_not_found")
func ipcPMProfileNotFound() async throws {
    let handlers = makeContractHandlers(getPMProfile: { id in
        throw PMProfileStoreError.profileNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/profile?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_profile_not_found")
}

@Test("POST /pm/profile/upsert invalid JSON returns bad_request")
func ipcPMProfileUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/profile/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/profile/upsert returns success envelope")
func ipcPMProfileUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/profile/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMProfile(id: "pm-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["pmId"] == .string("pm-cli"))
}

@Test("GET /pm/mandates returns success envelope with array")
func ipcPMMandatesRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/mandates",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let mandates = envelope.result?.arrayValue ?? []
    #expect(mandates.count == 1)
}

@Test("GET /pm/mandate missing id returns bad_request")
func ipcPMMandateMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/mandate",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/mandate not found returns pm_mandate_not_found")
func ipcPMMandateNotFound() async throws {
    let handlers = makeContractHandlers(getPMMandate: { id in
        throw PMMandateStoreError.mandateNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/mandate?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_mandate_not_found")
}

@Test("POST /pm/mandate/upsert invalid JSON returns bad_request")
func ipcPMMandateUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/mandate/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/mandate/upsert returns success envelope")
func ipcPMMandateUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/mandate/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMMandate(id: "mandate-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["mandateId"] == .string("mandate-cli"))
}

@Test("GET /pm/instructions returns success envelope with array")
func ipcPMInstructionsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/instructions",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let instructions = envelope.result?.arrayValue ?? []
    #expect(instructions.count == 1)
}

@Test("GET /pm/instruction missing id returns bad_request")
func ipcPMInstructionMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/instruction",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/instruction not found returns pm_instruction_not_found")
func ipcPMInstructionNotFound() async throws {
    let handlers = makeContractHandlers(getPMInstruction: { id in
        throw PMInstructionStoreError.instructionNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/instruction?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_instruction_not_found")
}

@Test("POST /pm/instruction/upsert invalid JSON returns bad_request")
func ipcPMInstructionUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/instruction/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/instruction/upsert returns success envelope")
func ipcPMInstructionUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/instruction/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMInstruction(id: "instruction-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["instructionId"] == .string("instruction-cli"))
}

@Test("GET /pm/notebook returns success envelope with array")
func ipcPMNotebookRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/notebook",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let notes = envelope.result?.arrayValue ?? []
    #expect(notes.count == 1)
}

@Test("GET /pm/notebook-entry missing id returns bad_request")
func ipcPMNotebookEntryMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/notebook-entry",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/notebook-entry not found returns pm_notebook_entry_not_found")
func ipcPMNotebookEntryNotFound() async throws {
    let handlers = makeContractHandlers(getPMNotebookEntry: { id in
        throw PMNotebookStoreError.entryNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/notebook-entry?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_notebook_entry_not_found")
}

@Test("POST /pm/notebook-entry/upsert invalid JSON returns bad_request")
func ipcPMNotebookEntryUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/notebook-entry/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/notebook-entry/upsert returns success envelope")
func ipcPMNotebookEntryUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/notebook-entry/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMNotebookEntry(id: "note-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["entryId"] == .string("note-cli"))
}

@Test("GET /pm/portfolio-strategy-brief returns success envelope")
func ipcPortfolioStrategyBriefGetSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/portfolio-strategy-brief",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["briefId"] == .string(PortfolioStrategyBrief.singletonID))
    #expect(envelope.result?.objectValue?["updatedBy"] == .string("pm-primary"))
}

@Test("POST /pm/portfolio-strategy-brief/upsert returns success envelope")
func ipcPortfolioStrategyBriefUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/portfolio-strategy-brief/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(
                PortfolioStrategyBrief(
                    objectiveSummary: "Escalate earnings and guidance changes for held names.",
                    currentRiskPosture: "Moderate risk posture.",
                    reviewEscalationPosture: "PM review first.",
                    updatedBy: "pm-primary",
                    updateSource: .pmControlPlane,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
                )
            )
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["objectiveSummary"] == .string("Escalate earnings and guidance changes for held names."))
    #expect(envelope.result?.objectValue?["updateSource"] == .string(PortfolioStrategyBriefUpdateSource.pmControlPlane.rawValue))
}

@Test("GET /pm/recent-news-analyst-runtime returns success envelope")
func ipcRecentNewsAnalystRuntimeGetSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/recent-news-analyst-runtime",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["settingsId"] == .string(RecentNewsAnalystRuntimeSettings.singletonID))
    #expect(envelope.result?.objectValue?["runtimeIdentifier"] == .string("gpt-4.1-mini"))
}

@Test("POST /pm/recent-news-analyst-runtime/upsert returns success envelope")
func ipcRecentNewsAnalystRuntimeUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/recent-news-analyst-runtime/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(
                RecentNewsAnalystRuntimeSettings(
                    runtimeIdentifier: "gpt-4.1-nano",
                    reasoningMode: .standard,
                    updatedBy: "pm-primary",
                    updateSource: .pmControlPlane,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
                )
            )
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["runtimeIdentifier"] == .string("gpt-4.1-nano"))
    #expect(envelope.result?.objectValue?["updateSource"] == .string(RecentNewsAnalystRuntimeSettingsUpdateSource.pmControlPlane.rawValue))
}

@Test("GET /pm/standing-bench-analyst-runtime returns success envelope")
func ipcStandingBenchAnalystRuntimeGetSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/standing-bench-analyst-runtime",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["settingsId"] == .string(StandingBenchAnalystRuntimeSettings.singletonID))
    #expect(envelope.result?.objectValue?["runtimeIdentifier"] == .string("gpt-4.1"))
}

@Test("POST /pm/standing-bench-analyst-runtime/upsert returns success envelope")
func ipcStandingBenchAnalystRuntimeUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/standing-bench-analyst-runtime/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(
                StandingBenchAnalystRuntimeSettings(
                    runtimeIdentifier: "gpt-5.4",
                    reasoningMode: .deliberate,
                    updatedBy: "pm-primary",
                    updateSource: .pmControlPlane,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
                )
            )
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["runtimeIdentifier"] == .string("gpt-5.4"))
    #expect(envelope.result?.objectValue?["updateSource"] == .string(StandingBenchAnalystRuntimeSettingsUpdateSource.pmControlPlane.rawValue))
}

@Test("GET /pm/decisions returns success envelope with array")
func ipcPMDecisionsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/decisions",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let decisions = envelope.result?.arrayValue ?? []
    #expect(decisions.count == 1)
    #expect(decisions.first?.objectValue?["decisionId"] == .string("decision-1"))
}

@Test("GET /pm/decision missing id returns bad_request")
func ipcPMDecisionMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/decision",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/decision not found returns pm_decision_not_found")
func ipcPMDecisionNotFound() async throws {
    let handlers = makeContractHandlers(getPMDecision: { id in
        throw PMDecisionStoreError.decisionNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/decision?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_decision_not_found")
}

@Test("POST /pm/decision/upsert invalid JSON returns bad_request")
func ipcPMDecisionUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/decision/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/decision/upsert returns success envelope")
func ipcPMDecisionUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/decision/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMDecision(id: "decision-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["decisionId"] == .string("decision-cli"))
}

@Test("GET /pm/approval-requests returns success envelope with array")
func ipcPMApprovalRequestsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/approval-requests",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let requests = envelope.result?.arrayValue ?? []
    #expect(requests.count == 1)
    #expect(requests.first?.objectValue?["approvalRequestId"] == .string("approval-1"))
}

@Test("GET /pm/approval-request missing id returns bad_request")
func ipcPMApprovalRequestMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/approval-request",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/approval-request not found returns pm_approval_request_not_found")
func ipcPMApprovalRequestNotFound() async throws {
    let handlers = makeContractHandlers(getPMApprovalRequest: { id in
        throw PMApprovalRequestStoreError.approvalRequestNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/approval-request?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_approval_request_not_found")
}

@Test("POST /pm/approval-request/upsert invalid JSON returns bad_request")
func ipcPMApprovalRequestUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/approval-request/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/approval-request/upsert returns success envelope")
func ipcPMApprovalRequestUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/approval-request/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMApprovalRequest(id: "approval-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["approvalRequestId"] == .string("approval-cli"))
}

@Test("GET /pm/execution-readiness missing approvalRequestId returns bad_request")
func ipcPMExecutionReadinessMissingApprovalRequestID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/execution-readiness",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/execution-readiness returns success envelope")
func ipcPMExecutionReadinessSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/execution-readiness?approvalRequestId=approval-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["approvalRequestId"] == .string("approval-1"))
    #expect(envelope.result?.objectValue?["status"] == .string("blocked_missing_proposal_approval"))
}

@Test("POST /pm/execution/route returns success envelope")
func ipcPMExecutionRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/execution/route",
            headers: ["x-agent-token": "token-123", "content-type": "application/json"],
            body: Data("{\"approvalRequestId\":\"approval-1\"}".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["status"] == .string("routed_successfully"))
}

@Test("POST /pm/execution/route can return explicit local-app-required Live block")
func ipcPMExecutionRouteLiveReviewBlockedEnvelope() async throws {
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: makeContractHandlers(
            routePMExecutionApprovedIntent: { approvalRequestID in
                PMExecutionRoutingAssessment(
                    approvalRequestId: approvalRequestID,
                    decisionId: nil,
                    proposalId: nil,
                    proposalTitle: nil,
                    proposalStatus: nil,
                    environment: .live,
                    isLiveArmed: true,
                    killSwitchEnabled: false,
                    status: .blockedExecutionPrerequisites,
                    action: .none,
                    summary: "Live order routing must be completed in the Mac app.",
                    detail: "Ordinary IPC cannot submit Live order reviews.",
                    blockedReasons: [.localAppRequiredForLiveExecution]
                )
            }
        )
    )
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/execution/route",
            headers: ["x-agent-token": "token-123", "content-type": "application/json"],
            body: Data("{\"approvalRequestId\":\"approval-live-ipc\"}".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    let result = try #require(envelope.result?.objectValue)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(result["approvalRequestId"] == .string("approval-live-ipc"))
    #expect(result["status"] == .string("blocked_execution_prerequisites"))
    #expect(result["action"] == .string("none"))
    #expect(result["summary"]?.stringValue?.contains("Mac app") == true)
    #expect(result["blockedReasons"]?.arrayValue == [.string("local_app_required_for_live_execution")])
}

@Test("GET /pm/communication-sessions returns success envelope with array")
func ipcPMCommunicationSessionsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-sessions",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let sessions = envelope.result?.arrayValue ?? []
    #expect(sessions.count == 1)
    #expect(sessions.first?.objectValue?["sessionId"] == .string("session-1"))
}

@Test("GET /pm/communication-session missing id returns bad_request")
func ipcPMCommunicationSessionMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-session",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/communication-session not found returns pm_communication_session_not_found")
func ipcPMCommunicationSessionNotFound() async throws {
    let handlers = makeContractHandlers(getPMCommunicationSession: { id in
        throw PMCommunicationSessionStoreError.sessionNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-session?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_communication_session_not_found")
}

@Test("POST /pm/communication-session/upsert invalid JSON returns bad_request")
func ipcPMCommunicationSessionUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/communication-session/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/communication-session/upsert returns success envelope")
func ipcPMCommunicationSessionUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/communication-session/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMCommunicationSession(id: "session-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["sessionId"] == .string("session-cli"))
}

@Test("GET /pm/communication-messages returns success envelope with array")
func ipcPMCommunicationMessagesRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-messages",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let messages = envelope.result?.arrayValue ?? []
    #expect(messages.count == 1)
    #expect(messages.first?.objectValue?["messageId"] == .string("message-1"))
}

@Test("GET /pm/communication-message missing id returns bad_request")
func ipcPMCommunicationMessageMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-message",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/communication-message not found returns pm_communication_message_not_found")
func ipcPMCommunicationMessageNotFound() async throws {
    let handlers = makeContractHandlers(getPMCommunicationMessage: { id in
        throw PMCommunicationMessageStoreError.messageNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/communication-message?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_communication_message_not_found")
}

@Test("POST /pm/communication-message/upsert invalid JSON returns bad_request")
func ipcPMCommunicationMessageUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/communication-message/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/communication-message/upsert returns success envelope")
func ipcPMCommunicationMessageUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/communication-message/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMCommunicationMessage(id: "message-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["messageId"] == .string("message-cli"))
}

@Test("GET /pm/delegations returns success envelope with array")
func ipcPMDelegationsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/delegations",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let delegations = envelope.result?.arrayValue ?? []
    #expect(delegations.count == 1)
    #expect(delegations.first?.objectValue?["delegationId"] == .string("delegation-1"))
}

@Test("GET /pm/delegation missing id returns bad_request")
func ipcPMDelegationMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/delegation",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /pm/delegation not found returns pm_delegation_not_found")
func ipcPMDelegationNotFound() async throws {
    let handlers = makeContractHandlers(getPMDelegation: { id in
        throw PMDelegationStoreError.delegationNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/pm/delegation?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "pm_delegation_not_found")
}

@Test("POST /pm/delegation/upsert invalid JSON returns bad_request")
func ipcPMDelegationUpsertInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/delegation/upsert invalid runtime policy returns validation error")
func ipcPMDelegationUpsertInvalidRuntimePolicy() async throws {
    let handlers = makeContractHandlers(upsertPMDelegation: { delegation in
        if delegation.runtimePolicyOverride?.runtimeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            throw AnalystRuntimePolicyValidationError.runtimeIdentifierRequired
        }
        return delegation
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    var delegation = makeContractPMDelegation(id: "delegation-invalid")
    delegation.runtimePolicyOverride = AnalystRuntimePolicy(
        runtimeIdentifier: "  ",
        reasoningMode: .deliberate,
        policySource: .pmDelegationOverride,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(delegation)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_runtime_policy_invalid")
}

@Test("POST /pm/delegation/upsert returns success envelope")
func ipcPMDelegationUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractPMDelegation(id: "delegation-cli"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["delegationId"] == .string("delegation-cli"))
}

@Test("POST /pm/delegation/follow-up invalid JSON returns bad_request")
func ipcPMDelegationFollowUpInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/follow-up",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/delegation/follow-up returns success envelope")
func ipcPMDelegationFollowUpSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/follow-up",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(
                PMDelegationFollowUpRequest(
                    sourceDelegationId: "delegation-1",
                    actionType: .rerunWithRuntime,
                    summary: "Challenge the prior memo.",
                    requestedCharterId: "charter-1",
                    requestedRuntimePolicy: AnalystRuntimePolicy(
                        runtimeIdentifier: "gpt-5",
                        reasoningMode: .deliberate,
                        policySource: .pmDelegationOverride,
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
                    ),
                    taskingBrief: PMTaskingBrief(taskObjective: "Challenge the prior memo.")
                )
            )
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["createdDelegationId"] == .string("delegation-follow-up-1"))
}

@Test("POST /pm/delegation/launch missing delegationId returns bad_request")
func ipcPMDelegationLaunchMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/launch",
            headers: ["x-agent-token": "token-123"],
            body: Data("{\"draftSignal\":true}".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/delegation/launch invalid proposal selection returns bad_request")
func ipcPMDelegationLaunchInvalidDraftSelection() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/launch",
            headers: ["x-agent-token": "token-123"],
            body: Data("{\"delegationId\":\"delegation-1\",\"draftProposal\":true}".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /pm/delegation/launch returns success envelope")
func ipcPMDelegationLaunchSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/pm/delegation/launch",
            headers: ["x-agent-token": "token-123"],
            body: Data("{\"delegationId\":\"delegation-1\",\"draftSignal\":true}".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["delegationId"] == .string("delegation-1"))
    #expect(envelope.result?.objectValue?["draftedSignalId"] == .string("sig-1"))
}

@Test("GET /analyst/charters returns success envelope with array")
func ipcAnalystChartersRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/charters",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let charters = envelope.result?.arrayValue ?? []
    #expect(charters.count == 1)
}

@Test("GET /analyst/charter missing id returns bad_request")
func ipcAnalystCharterMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/charter",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /analyst/charter not found returns analyst_charter_not_found")
func ipcAnalystCharterNotFound() async throws {
    let handlers = makeContractHandlers(getAnalystCharter: { id in
        throw AnalystCharterStoreError.charterNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/charter?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_charter_not_found")
}

@Test("POST /analyst/charter/upsert returns success envelope")
func ipcAnalystCharterUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/charter/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(makeContractAnalystCharter(id: "charter-upsert"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["charterId"] == .string("charter-upsert"))
}

@Test("GET /analyst/tasks returns success envelope with array")
func ipcAnalystTasksRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/tasks",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let tasks = envelope.result?.arrayValue ?? []
    #expect(tasks.count == 1)
}

@Test("POST /analyst/task/upsert returns success envelope")
func ipcAnalystTaskUpsertRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/task/upsert",
            headers: [
                "x-agent-token": "token-123",
                "content-type": "application/json"
            ],
            body: try encoder.encode(makeContractAnalystTask(id: "task-upsert"))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["taskId"] == .string("task-upsert"))
}

@Test("GET /analyst/finding not found returns analyst_finding_not_found")
func ipcAnalystFindingNotFound() async throws {
    let handlers = makeContractHandlers(getAnalystFinding: { id in
        throw AnalystFindingStoreError.findingNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/finding?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_finding_not_found")
}

@Test("GET /analyst/memo returns success envelope")
func ipcAnalystMemoGetSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/memo?id=memo-1",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["memoId"] == .string("memo-1"))
    #expect(envelope.result?.objectValue?["findingId"] == .string("finding-1"))
}

@Test("GET /analyst/memos returns success envelope with array")
func ipcAnalystMemosRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/memos",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let memos = envelope.result?.arrayValue ?? []
    #expect(memos.count == 1)
    #expect(memos.first?.objectValue?["memoId"] == .string("memo-1"))
}

@Test("GET /analyst/memo not found returns analyst_memo_not_found")
func ipcAnalystMemoNotFound() async throws {
    let handlers = makeContractHandlers(getAnalystMemo: { id in
        throw AnalystMemoStoreError.memoNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/memo?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_memo_not_found")
}

@Test("GET /analyst/news invalid since returns bad_request with ISO8601 guidance")
func ipcAnalystNewsRouteInvalidSince() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/analyst/news?since=not-a-date",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
    #expect(envelope.error?.message.contains("ISO8601") == true)
}

@Test("POST /analyst/evidence-bundle/upsert invalid body returns bad_request")
func ipcAnalystEvidenceBundleUpsertBadRequest() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/evidence-bundle/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /analyst/finding/upsert returns success envelope")
func ipcAnalystFindingUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let finding = makeContractAnalystFinding(id: "finding-upserted")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/finding/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(finding)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["findingId"] == .string("finding-upserted"))
}

@Test("POST /analyst/memo/upsert returns success envelope")
func ipcAnalystMemoUpsertSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let memo = makeContractAnalystMemo(id: "memo-upserted")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/memo/upsert",
            headers: ["x-agent-token": "token-123"],
            body: try encoder.encode(memo)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["memoId"] == .string("memo-upserted"))
}

@Test("POST /analyst/memo/upsert invalid body returns bad_request")
func ipcAnalystMemoUpsertBadRequest() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/memo/upsert",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /analyst/finding/draft-signal returns success envelope")
func ipcAnalystFindingDraftSignalSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/finding/draft-signal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["findingId": .string("finding-1")]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["signalId"] == .string("sig-finding-1"))
    #expect(envelope.result?.objectValue?["originatingFindingId"] == .string("finding-1"))
}

@Test("POST /analyst/finding/draft-signal missing findingId returns bad_request")
func ipcAnalystFindingDraftSignalMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/finding/draft-signal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([:]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /analyst/finding/draft-signal ineligible finding returns validation error")
func ipcAnalystFindingDraftSignalIneligible() async throws {
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: makeContractHandlers(draftSignalFromAnalystFinding: { id in
            throw AnalystFindingSignalDraftError.ineligibleFinding(id: id, reason: "directional content missing")
        })
    )
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/finding/draft-signal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["findingId": .string("finding-1")]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_finding_signal_ineligible")
}

@Test("POST /analyst/signal/draft-proposal returns success envelope")
func ipcAnalystSignalDraftProposalSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/signal/draft-proposal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "signalId": .string("sig-1"),
                "strategyId": .string("heartbeat")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    #expect(envelope.result?.objectValue?["proposalId"] == .string("proposal-sig-1"))
    #expect(envelope.result?.objectValue?["originatingSignalId"] == .string("sig-1"))
}

@Test("POST /analyst/signal/draft-proposal missing signalId returns bad_request")
func ipcAnalystSignalDraftProposalMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/signal/draft-proposal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([:]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /analyst/signal/draft-proposal ineligible signal returns validation error")
func ipcAnalystSignalDraftProposalIneligible() async throws {
    let router = AgentControlRouter(
        authToken: "token-123",
        handlers: makeContractHandlers(draftProposalFromAnalystSignal: { id, _ in
            throw AnalystSignalProposalDraftError.ineligibleSignal(id: id, reason: "signal is missing analyst provenance")
        })
    )
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/analyst/signal/draft-proposal",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["signalId": .string("sig-1")]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "analyst_signal_proposal_ineligible")
}

@Test("POST /replay/run invalid date field returns bad_request with ISO8601 guidance")
func ipcReplayRunInvalidDate() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let body = try JSONEncoder().encode(
        JSONValue.object([
            "proposalId": .string("proposal-1"),
            "symbols": .array([.string("AAPL")]),
            "timeframe": .string("1Min"),
            "start": .string("not-a-date"),
            "end": .string("2026-02-05T00:00:00.000Z"),
            "speed": .string("fast"),
            "autoIngest": .bool(true),
            "feed": .string("iex"),
            "simulateTrades": .bool(false),
            "allowTradingInReplay": .bool(false),
            "fillPolicy": .string("next_open_market"),
            "slippageBps": .object([
                "market": .number(0),
                "limit": .number(0)
            ])
        ])
    )
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/replay/run",
            headers: ["x-agent-token": "token-123"],
            body: body
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
    #expect(envelope.error?.message.contains("ISO8601") == true)
}

@Test("GET /signals returns success envelope with array")
func ipcSignalsRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/signals?limit=10",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let signals = envelope.result?.arrayValue ?? []
    #expect(signals.count == 1)
}

@Test("GET /signal missing id returns bad_request")
func ipcSignalGetMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/signal",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /signal not found returns signal_not_found")
func ipcSignalGetNotFound() async throws {
    let handlers = makeContractHandlers(getSignal: { id in
        throw SignalStoreError.signalNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/signal?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "signal_not_found")
}

@Test("POST /jobs/submit missing type returns bad_request")
func ipcJobSubmitMissingType() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/jobs/submit",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object(["params": .object([:])]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /job not found returns job_not_found")
func ipcJobNotFound() async throws {
    let handlers = makeContractHandlers(getJob: { id in
        throw JobStoreError.jobNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/job?id=missing-job",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "job_not_found")
}

@Test("GET /schedules returns success envelope with array")
func ipcSchedulesRouteSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/schedules",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let schedules = envelope.result?.arrayValue ?? []
    #expect(schedules.count == 1)
}

@Test("GET /schedule missing id returns bad_request")
func ipcScheduleMissingID() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/schedule",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /schedule not found returns schedule_not_found")
func ipcScheduleNotFound() async throws {
    let handlers = makeContractHandlers(getSchedule: { _ in nil })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/schedule?id=missing",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "schedule_not_found")
}

@Test("POST /schedule/enable missing enabled returns bad_request")
func ipcScheduleEnableBadRequest() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/schedule/enable",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "id": .string("schedule-1")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /schedule/run-now not found returns schedule_not_found")
func ipcScheduleRunNowNotFound() async throws {
    let handlers = makeContractHandlers(runScheduleNow: { id in
        throw ScheduleStoreError.scheduleNotFound(id: id)
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/schedule/run-now",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "id": .string("missing")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 404)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "schedule_not_found")
}

@Test("POST /schedule/run-now success returns running job id")
func ipcScheduleRunNowSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/schedule/run-now",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "id": .string("schedule-1")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["scheduleId"] == .string("schedule-1"))
    #expect(object["runningJobId"] == .string("job-1"))
    #expect(object["lastRunAt"] != nil)
}

@Test("POST /schedule/run-now can return periodic completion summary without job_not_found")
func ipcScheduleRunNowPeriodicCompletionSummary() async throws {
    let completedAt = Date(timeIntervalSince1970: 1_700_000_222)
    let handlers = makeContractHandlers(runScheduleNow: { id in
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: id,
                jobType: .rssPoll,
                enabled: true,
                trigger: ScheduledJobTrigger(intervalSec: 60),
                policy: ScheduledJobPolicy(
                    runMode: .periodic,
                    restartOnAppLaunch: true,
                    maxRuntimeSec: nil,
                    allowOverlap: false
                ),
                params: [:],
                lastRunAt: completedAt,
                lastRunJobId: "job-2",
                lastRunStatus: .succeeded,
                lastRunSummary: "rss_poll: feeds=3 parsed=52 new=12 dup=40 failed=0",
                lastSuccessAt: completedAt,
                nextRunAt: completedAt.addingTimeInterval(60)
            )
        )
    })
    let router = AgentControlRouter(authToken: "token-123", handlers: handlers)
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/schedule/run-now",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "id": .string("schedule-1")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["runningJobId"] == nil)
    #expect(object["lastRunStatus"] == .string("succeeded"))
    #expect(object["lastRunSummary"] == .string("rss_poll: feeds=3 parsed=52 new=12 dup=40 failed=0"))
    #expect(object["lastError"] == nil)
}

@Test("GET /retention-policy returns success envelope")
func ipcRetentionPolicyGetSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/retention-policy",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    let audit = try #require(object["audit"]?.objectValue)
    #expect(audit["rotateWhenMB"]?.intValue == 25)
}

@Test("POST /retention-policy/update invalid body returns bad_request")
func ipcRetentionPolicyUpdateInvalidBody() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/retention-policy/update",
            headers: ["x-agent-token": "token-123"],
            body: Data("not-json".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /maintenance/run missing dryRun returns bad_request")
func ipcMaintenanceRunMissingDryRun() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/run",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([:]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /maintenance/run returns queued job summary")
func ipcMaintenanceRunSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/run",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "dryRun": .bool(true)
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["jobId"] == .string("job-maintenance-1"))
}

@Test("POST /maintenance/run rejects invalid job telemetry cutoff")
func ipcMaintenanceRunRejectsInvalidJobTelemetryCutoff() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/run",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "dryRun": .bool(true),
                "jobTelemetryCleanupBefore": .string("not-a-date")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /maintenance/run accepts explicit job telemetry cutoff")
func ipcMaintenanceRunAcceptsJobTelemetryCutoff() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/run",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "dryRun": .bool(true),
                "jobTelemetryCleanupBefore": .string("2026-04-29T00:00:00Z")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["dryRun"] == .bool(true))
    #expect(object["jobTelemetryCleanupBefore"]?.stringValue?.hasPrefix("2026-04-29T00:00:00") == true)
}

@Test("POST /maintenance/memory-relief force returns aggregate summary")
func ipcMaintenanceMemoryReliefForceSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/memory-relief",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "force": .bool(true),
                "dryRun": .bool(false),
                "reason": .string("test_force")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["available"] == .bool(true))
    #expect(object["force"] == .bool(true))
    #expect(object["dryRun"] == .bool(false))
    #expect(object["reason"] == .string("test_force"))
    #expect(object["actionApplied"] == .bool(true))
}

@Test("POST /maintenance/memory-relief dry-run does not apply action")
func ipcMaintenanceMemoryReliefDryRunSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/memory-relief",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "dryRun": .bool(true)
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["dryRun"] == .bool(true))
    #expect(object["force"] == .bool(false))
    #expect(object["actionApplied"] == .bool(false))
}

@Test("POST /maintenance/memory-relief rejects malformed booleans")
func ipcMaintenanceMemoryReliefRejectsMalformedBooleans() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/memory-relief",
            headers: ["x-agent-token": "token-123"],
            body: try JSONEncoder().encode(JSONValue.object([
                "force": .string("yes")
            ]))
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("POST /maintenance/memory-relief rejects invalid JSON")
func ipcMaintenanceMemoryReliefRejectsInvalidJSON() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "POST",
            path: "/maintenance/memory-relief",
            headers: ["x-agent-token": "token-123"],
            body: Data("{".utf8)
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 400)
    #expect(envelope.ok == false)
    #expect(envelope.error?.code == "bad_request")
}

@Test("GET /maintenance/last returns maintenance summary")
func ipcMaintenanceLastSuccess() async throws {
    let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
    let response = await router.handle(
        IPCServerRequest(
            method: "GET",
            path: "/maintenance/last",
            headers: ["x-agent-token": "token-123"],
            body: Data()
        )
    )

    let envelope = try decodeEnvelope(response)
    #expect(response.statusCode == 200)
    #expect(envelope.ok == true)
    let object = try #require(envelope.result?.objectValue)
    #expect(object["jobId"] == .string("job-maintenance-1"))
}

@Test("Agent control docs include every supported route")
func ipcDocsContainSupportedRoutes() throws {
    let docs = try loadIPCDocs()
    for route in AgentControlRouter.supportedRoutes {
        let withHeading = "### \(route.method) `\(route.path)"
        let withMethodAndPath = "\(route.method) `\(route.path)"
        #expect(
            docs.contains(withHeading) || docs.contains(withMethodAndPath),
            "Missing route in docs/IPC.md: \(route.method) \(route.path)"
        )
    }
}

@Test("agentctl status maps to GET /status")
func agentctlStatusMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["status"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/status")
    #expect(request.jsonBody == nil)
}

@Test("agentctl analyst charter list maps to GET /analyst/charters")
func agentctlAnalystCharterListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["analyst", "charter", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/analyst/charters")
    #expect(request.jsonBody == nil)
}

@Test("agentctl analyst charter upsert maps to POST /analyst/charter/upsert")
func agentctlAnalystCharterUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["analyst", "charter", "upsert", "--file", "/tmp/charter.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractAnalystCharter(id: "charter-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/analyst/charter/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl analyst task upsert maps to POST /analyst/task/upsert")
func agentctlAnalystTaskUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["analyst", "task", "upsert", "--file", "/tmp/task.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractAnalystTask(id: "task-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/analyst/task/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl analyst finding upsert maps to POST /analyst/finding/upsert")
func agentctlAnalystFindingUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["analyst", "finding", "upsert", "--file", "/tmp/finding.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractAnalystFinding(id: "finding-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/analyst/finding/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl analyst finding draft-signal maps to POST /analyst/finding/draft-signal")
func agentctlAnalystFindingDraftSignalMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["analyst", "finding", "draft-signal", "--id", "finding-cli"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/analyst/finding/draft-signal")
    #expect(request.jsonBody == .object(["findingId": .string("finding-cli")]))
}

@Test("agentctl analyst signal draft-proposal maps to POST /analyst/signal/draft-proposal")
func agentctlAnalystSignalDraftProposalMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "analyst", "signal", "draft-proposal", "--id", "sig-cli", "--strategy", "heartbeat"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/analyst/signal/draft-proposal")
    #expect(request.jsonBody == .object([
        "signalId": .string("sig-cli"),
        "strategyId": .string("heartbeat")
    ]))
}

@Test("agentctl analyst news list maps to GET /analyst/news")
func agentctlAnalystNewsListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "analyst", "news", "list",
        "--limit", "5",
        "--since", "2026-03-02T12:34:56.123Z"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/analyst/news?limit=5&since=2026-03-02T12:34:56.123Z")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm profile list maps to GET /pm/profiles")
func agentctlPMProfileListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "profile", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/profiles")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm profile upsert maps to POST /pm/profile/upsert")
func agentctlPMProfileUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "profile", "upsert", "--file", "/tmp/pm-profile.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMProfile(id: "pm-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/profile/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm mandate get maps to GET /pm/mandate")
func agentctlPMMandateGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "mandate", "get", "mandate-cli"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/mandate?id=mandate-cli")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm instruction upsert maps to POST /pm/instruction/upsert")
func agentctlPMInstructionUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "instruction", "upsert", "--file", "/tmp/pm-instruction.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMInstruction(id: "instruction-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/instruction/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm notebook-entry list maps to GET /pm/notebook")
func agentctlPMNotebookEntryListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "notebook-entry", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/notebook")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm portfolio-strategy-brief get maps to GET /pm/portfolio-strategy-brief")
func agentctlPortfolioStrategyBriefGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "portfolio-strategy-brief", "get"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/portfolio-strategy-brief")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm portfolio-strategy-brief upsert maps to POST /pm/portfolio-strategy-brief/upsert")
func agentctlPortfolioStrategyBriefUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "portfolio-strategy-brief", "upsert", "--file", "/tmp/portfolio-strategy-brief.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(
            PortfolioStrategyBrief(
                objectiveSummary: "Keep event-aware tech exposure bounded.",
                currentRiskPosture: "Moderate risk.",
                reviewEscalationPosture: "Escalate to PM review first.",
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/portfolio-strategy-brief/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm recent-news-analyst-runtime get maps to GET /pm/recent-news-analyst-runtime")
func agentctlRecentNewsAnalystRuntimeGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "recent-news-analyst-runtime", "get"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/recent-news-analyst-runtime")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm recent-news-analyst-runtime upsert maps to POST /pm/recent-news-analyst-runtime/upsert")
func agentctlRecentNewsAnalystRuntimeUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "recent-news-analyst-runtime", "upsert", "--file", "/tmp/recent-news-runtime.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(
            RecentNewsAnalystRuntimeSettings(
                model: .gpt54,
                reasoningMode: .deliberate,
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/recent-news-analyst-runtime/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm decision list maps to GET /pm/decisions")
func agentctlPMDecisionListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "decision", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/decisions")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm decision upsert maps to POST /pm/decision/upsert")
func agentctlPMDecisionUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "decision", "upsert", "--file", "/tmp/pm-decision.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMDecision(id: "decision-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/decision/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm approval-request get maps to GET /pm/approval-request")
func agentctlPMApprovalRequestGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "approval-request", "get", "approval-cli"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/approval-request?id=approval-cli")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm approval-request upsert maps to POST /pm/approval-request/upsert")
func agentctlPMApprovalRequestUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "approval-request", "upsert", "--file", "/tmp/pm-approval-request.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMApprovalRequest(id: "approval-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/approval-request/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm communication-session list maps to GET /pm/communication-sessions")
func agentctlPMCommunicationSessionListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "communication-session", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/communication-sessions")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm communication-session upsert maps to POST /pm/communication-session/upsert")
func agentctlPMCommunicationSessionUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "communication-session", "upsert", "--file", "/tmp/pm-communication-session.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMCommunicationSession(id: "session-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/communication-session/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm communication-message get maps to GET /pm/communication-message")
func agentctlPMCommunicationMessageGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "communication-message", "get", "message-cli"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/communication-message?id=message-cli")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm communication-message upsert maps to POST /pm/communication-message/upsert")
func agentctlPMCommunicationMessageUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "communication-message", "upsert", "--file", "/tmp/pm-communication-message.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMCommunicationMessage(id: "message-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/communication-message/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm delegation get maps to GET /pm/delegation")
func agentctlPMDelegationGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "delegation", "get", "delegation-cli"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/pm/delegation?id=delegation-cli")
    #expect(request.jsonBody == nil)
}

@Test("agentctl pm delegation upsert maps to POST /pm/delegation/upsert")
func agentctlPMDelegationUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["pm", "delegation", "upsert", "--file", "/tmp/pm-delegation.json"])
    let request = try AlpacaAgentCtl.endpoint(for: command, fileLoader: { _ in
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
        return try encoder.encode(makeContractPMDelegation(id: "delegation-cli"))
    })

    #expect(request.method == "POST")
    #expect(request.path == "/pm/delegation/upsert")
    #expect(request.contentType == "application/json")
}

@Test("agentctl pm delegation launch maps to POST /pm/delegation/launch")
func agentctlPMDelegationLaunchMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "pm", "delegation", "launch", "--id", "delegation-cli", "--draft-signal", "--draft-proposal"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/pm/delegation/launch")
    #expect(request.jsonBody?.objectValue?["delegationId"] == .string("delegation-cli"))
    #expect(request.jsonBody?.objectValue?["draftSignal"] == .bool(true))
    #expect(request.jsonBody?.objectValue?["draftProposal"] == .bool(true))
}

@Test("agentctl pm exercise run parses optional control-plane exercise flags")
func agentctlPMExerciseRunParsesFlags() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "pm", "exercise", "run",
        "--pm-id", "pm-primary",
        "--charter-id", "charter-1",
        "--task-id", "task-1",
        "--scenario-label", "Synth Memo",
        "--runtime-id", "gpt-5",
        "--reasoning-mode", "deliberate",
        "--draft-signal",
        "--draft-proposal"
    ])

    switch command {
    case .pmExerciseRun(let options):
        #expect(options.pmId == "pm-primary")
        #expect(options.charterId == "charter-1")
        #expect(options.taskId == "task-1")
        #expect(options.scenarioLabel == "Synth Memo")
        #expect(options.runtimeIdentifier == "gpt-5")
        #expect(options.reasoningMode == .deliberate)
        #expect(options.draftSignal == true)
        #expect(options.draftProposal == true)
    default:
        Issue.record("Expected pm exercise run command")
    }
}

@Test("agentctl pm exercise quality-suite parses bounded flags")
func agentctlPMExerciseQualitySuiteParsesFlags() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "pm", "exercise", "quality-suite",
        "--pm-id", "pm-primary",
        "--charter-id", "charter-1"
    ])

    switch command {
    case .pmExerciseQualitySuite(let options):
        #expect(options.pmId == "pm-primary")
        #expect(options.charterId == "charter-1")
    default:
        Issue.record("Expected pm exercise quality-suite command")
    }
}

@Test("agentctl pm exercise workflow-suite parses bounded flags")
func agentctlPMExerciseWorkflowSuiteParsesFlags() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "pm", "exercise", "workflow-suite",
        "--pm-id", "pm-primary",
        "--charter-id", "charter-1"
    ])

    switch command {
    case .pmExerciseWorkflowSuite(let options):
        #expect(options.pmId == "pm-primary")
        #expect(options.charterId == "charter-1")
    default:
        Issue.record("Expected pm exercise workflow-suite command")
    }
}

@Test("agentctl pm exercise canonical-suite parses bounded flags")
func agentctlPMExerciseCanonicalSuiteParsesFlags() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "pm", "exercise", "canonical-suite",
        "--pm-id", "pm-primary",
        "--charter-id", "charter-1"
    ])

    switch command {
    case .pmExerciseCanonicalSuite(let options):
        #expect(options.pmId == "pm-primary")
        #expect(options.charterId == "charter-1")
    default:
        Issue.record("Expected pm exercise canonical-suite command")
    }
}

@Test("pm operational exercise uses real PM and analyst control-plane records and preserves bounded degraded output")
func pmOperationalExerciseCreatesBoundedArtifacts() async throws {
    actor RequestRecorder {
        private var values: [AgentCtlRequestSpec] = []

        func append(_ value: AgentCtlRequestSpec) {
            values.append(value)
        }

        func all() -> [AgentCtlRequestSpec] {
            values
        }
    }

    let now = Date(timeIntervalSince1970: 1_710_000_000)
    let recorder = RequestRecorder()

    let result = try await AlpacaAgentCtl.runPMOperationalExercise(
        options: PMOperationalExerciseOptions(
            pmId: nil,
            charterId: nil,
            taskId: nil,
            scenarioLabel: "Model Compare",
            taskTitleOverride: nil,
            taskDescriptionOverride: nil,
            taskTagsOverride: [],
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            draftSignal: true,
            draftProposal: false
        ),
        send: { spec in
            await recorder.append(spec)
            switch (spec.method, spec.path) {
            case ("GET", "/status"):
                return AgentControlEnvelope(ok: true, result: .object([:]))
            case ("GET", "/pm/profiles"):
                return try makeEnvelopeResult([PMProfile]())
            case ("POST", "/pm/profile/upsert"):
                let profile = try decodeSpecBody(spec, as: PMProfile.self)
                return try makeEnvelopeResult(profile)
            case ("GET", "/analyst/charters"):
                return try makeEnvelopeResult([AnalystCharter]())
            case ("POST", "/analyst/charter/upsert"):
                let charter = try decodeSpecBody(spec, as: AnalystCharter.self)
                return try makeEnvelopeResult(charter)
            case ("POST", "/analyst/task/upsert"):
                let task = try decodeSpecBody(spec, as: AnalystTask.self)
                return try makeEnvelopeResult(task)
            case ("POST", "/pm/delegation/upsert"):
                let delegation = try decodeSpecBody(spec, as: PMDelegationRecord.self)
                return try makeEnvelopeResult(delegation)
            case ("POST", "/pm/delegation/launch"):
                return try makeEnvelopeResult(
                    AnalystWorkerLaunchResult(
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "exercise-task-20240309160000",
                        delegationId: "exercise-delegation-20240309160000",
                        pmId: "pm-operational-exercise",
                        memoId: "memo-1",
                        memoTitle: "Scenario Memo",
                        findingId: "finding-1",
                        findingTitle: "Exercise finding",
                        draftedSignalId: "sig-1",
                        draftedProposalId: nil,
                        runtimeProvenance: AnalystRuntimeProvenance(
                            intendedPolicy: AnalystRuntimePolicy(
                                runtimeIdentifier: "gpt-5",
                                reasoningMode: .deliberate,
                                policySource: .pmDelegationOverride,
                                createdAt: now,
                                updatedAt: now
                            ),
                            actualRuntimeIdentifier: "deterministic_local",
                            actualReasoningMode: nil,
                            launchedAt: now
                        ),
                        externalEvidenceStatus: "degraded",
                        externalEvidenceIssueSummary: "category=no_approved_sources detail=charter=technology-innovation-research",
                        summary: "finding: Exercise finding",
                        outputExcerpt: "finding_id: finding-1"
                    )
                )
            case ("GET", "/analyst/memo?id=memo-1"):
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: "memo-1",
                        analystId: AnalystCharterSeed.analystId,
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "exercise-task-20240309160000",
                        delegationId: "exercise-delegation-20240309160000",
                        pmId: "pm-operational-exercise",
                        findingId: "finding-1",
                        evidenceBundleId: "bundle-1",
                        title: "Scenario Memo",
                        executiveSummary: "Bottom line: the current evidence supports a bounded PM review rather than an execution step.",
                        currentView: "The thesis is still provisional, but the PM now has enough readable context to decide whether to escalate.",
                        evidenceSummary: "The memo relies on recent app-owned news and bounded external support.",
                        uncertaintySummary: "External evidence was degraded and should keep confidence bounded.",
                        recommendedNextStep: "Turn this into a PM decision or approval request only if the PM agrees that the uncertainty is still acceptable for owner review.",
                        confidence: 0.68,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("POST", "/pm/decision/upsert"):
                let decision = try decodeSpecBody(spec, as: PMDecisionRecord.self)
                return try makeEnvelopeResult(decision)
            case ("POST", "/pm/approval-request/upsert"):
                let approvalRequest = try decodeSpecBody(spec, as: PMApprovalRequest.self)
                return try makeEnvelopeResult(approvalRequest)
            default:
                Issue.record("Unexpected request \(spec.method) \(spec.path)")
                return AgentControlEnvelope(
                    ok: false,
                    error: AgentControlErrorBody(code: "unexpected_request", message: "\(spec.method) \(spec.path)")
                )
            }
        },
        now: { now }
    )

    let requests = await recorder.all()

    #expect(result.pmId == "pm-operational-exercise")
    #expect(result.charterId == AnalystCharterSeed.charterId)
    #expect(result.taskCreated == true)
    #expect(result.taskId == "exercise-task-20240309160000")
    #expect(result.delegationId == "exercise-delegation-20240309160000")
    #expect(result.decisionId == "exercise-decision-20240309160000")
    #expect(result.approvalRequestId == "exercise-approval-request-20240309160000")
    #expect(result.scenarioLabel == "Model Compare")
    #expect(result.findingId == "finding-1")
    #expect(result.memoId == "memo-1")
    #expect(result.memoTitle == "Scenario Memo")
    #expect(result.draftedSignalId == "sig-1")
    #expect(result.draftedProposalId == nil)
    #expect(result.intendedRuntimeIdentifier == "gpt-5")
    #expect(result.actualRuntimeIdentifier == "deterministic_local")
    #expect(result.externalEvidenceStatus == "degraded")

    #expect(requests.map(\.path) == [
        "/status",
        "/pm/profiles",
        "/pm/profile/upsert",
        "/analyst/charters",
        "/analyst/charter/upsert",
        "/analyst/task/upsert",
        "/pm/delegation/upsert",
        "/pm/delegation/launch",
        "/analyst/memo?id=memo-1",
        "/pm/decision/upsert",
        "/pm/approval-request/upsert"
    ])

    let createdDelegation = try decodeSpecBody(requests[6], as: PMDelegationRecord.self)
    #expect(createdDelegation.pmId == "pm-operational-exercise")
    #expect(createdDelegation.charterId == AnalystCharterSeed.charterId)
    #expect(createdDelegation.taskId == "exercise-task-20240309160000")
    #expect(createdDelegation.runtimePolicyOverride?.runtimeIdentifier == "gpt-5")
    #expect(createdDelegation.requestedOutputs == [.finding, .checkpointUpdate, .signal])

    let createdDecision = try decodeSpecBody(requests[9], as: PMDecisionRecord.self)
    #expect(createdDecision.delegationId == "exercise-delegation-20240309160000")
    #expect(createdDecision.findingId == "finding-1")
    #expect(createdDecision.signalId == "sig-1")
    #expect(createdDecision.title.contains("Scenario Memo"))
    #expect(createdDecision.summary.contains("bounded PM review"))
    #expect(createdDecision.summary.contains("Recommended next step"))

    let createdApprovalRequest = try decodeSpecBody(requests[10], as: PMApprovalRequest.self)
    #expect(createdApprovalRequest.decisionId == "exercise-decision-20240309160000")
    #expect(createdApprovalRequest.delegationId == "exercise-delegation-20240309160000")
    #expect(createdApprovalRequest.signalId == "sig-1")
    #expect(createdApprovalRequest.status == .pending)
    #expect(createdApprovalRequest.subject.contains("Scenario Memo"))
    #expect(createdApprovalRequest.rationale.contains("bounded PM review"))
    #expect(createdApprovalRequest.rationale.contains("does not approve trading"))
}

@Test("pm operational quality suite runs comparable multi-model scenarios")
func pmOperationalExerciseQualitySuiteRunsComparableModels() async throws {
    actor RequestRecorder {
        private var values: [AgentCtlRequestSpec] = []
        func append(_ value: AgentCtlRequestSpec) { values.append(value) }
        func all() -> [AgentCtlRequestSpec] { values }
    }
    actor LaunchCounter {
        private var value = 0
        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }

    let now = Date(timeIntervalSince1970: 1_710_000_100)
    let recorder = RequestRecorder()
    let counter = LaunchCounter()

    let result = try await AlpacaAgentCtl.runPMOperationalExerciseQualitySuite(
        options: PMOperationalExerciseQualitySuiteOptions(pmId: "pm-qa", charterId: "charter-qa"),
        send: { spec in
            await recorder.append(spec)
            switch (spec.method, spec.path) {
            case ("GET", "/status"):
                return AgentControlEnvelope(ok: true, result: .object([:]))
            case ("GET", "/pm/profiles"):
                return try makeEnvelopeResult([
                    PMProfile(
                        pmId: "pm-qa",
                        displayName: "QA PM",
                        roleSummary: "Bounded QA PM",
                        createdAt: now,
                        updatedAt: now
                    )
                ])
            case ("GET", "/analyst/charters"):
                return try makeEnvelopeResult([
                    AnalystCharter(
                        charterId: "charter-qa",
                        analystId: "analyst-qa",
                        title: "QA Analyst",
                        coverageScope: "Tech",
                        strategyFamily: "Long/short",
                        summary: "QA charter",
                        duties: ["Test memo quality"],
                        constraints: ["No auto-trade"],
                        expectedOutputs: ["Readable memos"],
                        allowedSources: ["app_news"],
                        createdAt: now,
                        updatedAt: now
                    )
                ])
            case ("POST", "/analyst/task/upsert"):
                let task = try decodeSpecBody(spec, as: AnalystTask.self)
                return try makeEnvelopeResult(task)
            case ("POST", "/pm/delegation/upsert"):
                let delegation = try decodeSpecBody(spec, as: PMDelegationRecord.self)
                return try makeEnvelopeResult(delegation)
            case ("POST", "/pm/delegation/launch"):
                let delegationId = spec.jsonBody?.objectValue?["delegationId"]?.stringValue ?? "delegation"
                let launchIndex = await counter.next()
                let runtime = launchIndex == 0 || launchIndex == 2 ? "gpt-5" : "gpt-4.1-mini"
                let memoId = "memo-\(delegationId)"
                return try makeEnvelopeResult(
                    AnalystWorkerLaunchResult(
                        charterId: "charter-qa",
                        taskId: "task-\(delegationId)",
                        delegationId: delegationId,
                        pmId: "pm-qa",
                        memoId: memoId,
                        memoTitle: "Memo \(delegationId)",
                        findingId: "finding-\(delegationId)",
                        findingTitle: "Finding \(delegationId)",
                        draftedSignalId: nil,
                        draftedProposalId: nil,
                        runtimeProvenance: AnalystRuntimeProvenance(
                            intendedPolicy: AnalystRuntimePolicy(
                                runtimeIdentifier: runtime,
                                reasoningMode: runtime == "gpt-5" ? .deliberate : .standard,
                                policySource: .pmDelegationOverride,
                                createdAt: now,
                                updatedAt: now
                            ),
                            actualRuntimeIdentifier: "deterministic_local[\(runtime)]",
                            actualReasoningMode: runtime == "gpt-5" ? .deliberate : .standard,
                            launchedAt: now
                        ),
                        externalEvidenceStatus: "ok",
                        externalEvidenceIssueSummary: nil,
                        summary: "summary",
                        outputExcerpt: "memo_id: \(memoId)"
                    )
                )
            case ("GET", let path) where path.hasPrefix("/analyst/memo?id="):
                let memoId = path.replacingOccurrences(of: "/analyst/memo?id=", with: "")
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: memoId,
                        analystId: "analyst-qa",
                        charterId: "charter-qa",
                        taskId: "task-\(memoId)",
                        delegationId: memoId.replacingOccurrences(of: "memo-", with: ""),
                        pmId: "pm-qa",
                        findingId: "finding-\(memoId)",
                        evidenceBundleId: "bundle-\(memoId)",
                        title: "Memo \(memoId)",
                        executiveSummary: "Current read: scenario output for \(memoId).",
                        currentView: "Readable current view for \(memoId).",
                        evidenceSummary: "Evidence summary for \(memoId).",
                        uncertaintySummary: "Uncertainty summary for \(memoId).",
                        recommendedNextStep: "Recommended next step for \(memoId).",
                        confidence: 0.66,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("POST", "/pm/decision/upsert"):
                let decision = try decodeSpecBody(spec, as: PMDecisionRecord.self)
                return try makeEnvelopeResult(decision)
            case ("POST", "/pm/approval-request/upsert"):
                let approvalRequest = try decodeSpecBody(spec, as: PMApprovalRequest.self)
                return try makeEnvelopeResult(approvalRequest)
            case ("GET", "/pm/profile?id=pm-qa"), ("GET", "/analyst/charter?id=charter-qa"):
                Issue.record("Unexpected get-by-id path for quality suite")
                return AgentControlEnvelope(ok: false, error: AgentControlErrorBody(code: "unexpected_request", message: "unexpected"))
            default:
                Issue.record("Unexpected request \(spec.method) \(spec.path)")
                return AgentControlEnvelope(ok: false, error: AgentControlErrorBody(code: "unexpected_request", message: "\(spec.method) \(spec.path)"))
            }
        },
        now: { now }
    )

    #expect(result.suiteLabel == "pm_analyst_quality_suite")
    #expect(result.comparedTaskType == "synthesis")
    #expect(result.scenarioResults.count == 4)
    #expect(result.scenarioResults.map { $0.scenarioLabel } == [
        "Synthesis A — Deep",
        "Synthesis B — Concise",
        "Recommendation — PM escalation check",
        "Action Review — Owner readiness"
    ])
    #expect(result.scenarioResults[0].intendedRuntimeIdentifier == "gpt-5")
    #expect(result.scenarioResults[1].intendedRuntimeIdentifier == "gpt-4.1-mini")
    #expect(result.observations.contains(where: { $0.contains("Compared synthesis memo quality") }) == true)

    let requests = await recorder.all()
    let createdTasks = try requests
        .filter { $0.path == "/analyst/task/upsert" }
        .map { try decodeSpecBody($0, as: AnalystTask.self) }
    #expect(createdTasks.count == 4)
    #expect(createdTasks[0].title.contains("Synthesis Task"))
    #expect(createdTasks[2].title.contains("Recommendation Task"))
    #expect(createdTasks[3].title.contains("Action-adjacent review task"))
}

@Test("pm workflow suite exercises communication, approval, follow-up, and execution routing with watchlist-backed context")
func pmOperationalWorkflowSuiteUsesWatchlistBackedContext() async throws {
    actor RequestRecorder {
        private var values: [AgentCtlRequestSpec] = []
        func append(_ value: AgentCtlRequestSpec) { values.append(value) }
        func all() -> [AgentCtlRequestSpec] { values }
    }
    actor ReadinessCounter {
        private var value = 0
        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }
    actor WorkflowBriefState {
        private var brief: PortfolioStrategyBrief

        init(now: Date) {
            self.brief = PortfolioStrategyBrief(
                objectiveSummary: "Keep the watch universe current and bounded.",
                currentRiskPosture: "Moderate risk posture.",
                reviewEscalationPosture: "Escalate to PM review first.",
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: now,
                updatedAt: now
            )
        }

        func current() -> PortfolioStrategyBrief { brief }

        func update(_ updated: PortfolioStrategyBrief) -> PortfolioStrategyBrief {
            brief = updated
            return brief
        }
    }

    let now = Date(timeIntervalSince1970: 1_710_001_000)
    let recorder = RequestRecorder()
    let readinessCounter = ReadinessCounter()
    let briefState = WorkflowBriefState(now: now)

    let result = try await AlpacaAgentCtl.runPMOperationalWorkflowSuite(
        options: PMOperationalWorkflowSuiteOptions(pmId: nil, charterId: nil),
        send: { spec in
            await recorder.append(spec)
            switch (spec.method, spec.path) {
            case ("GET", "/status"):
                return AgentControlEnvelope(
                    ok: true,
                    result: .object([
                        "state": .string("ok"),
                        "watchlist": .array([.string("AAPL"), .string("MSFT"), .string("NVDA")])
                    ])
                )
            case ("GET", "/pm/profiles"):
                return try makeEnvelopeResult([PMProfile]())
            case ("POST", "/pm/profile/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMProfile.self))
            case ("GET", "/analyst/charters"):
                return try makeEnvelopeResult([AnalystCharter]())
            case ("POST", "/analyst/charter/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystCharter.self))
            case ("GET", "/pm/portfolio-strategy-brief"):
                return try makeEnvelopeResult(await briefState.current())
            case ("POST", "/pm/portfolio-strategy-brief/upsert"):
                return try makeEnvelopeResult(await briefState.update(try decodeSpecBody(spec, as: PortfolioStrategyBrief.self)))
            case ("POST", "/pm/communication-session/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationSession.self))
            case ("POST", "/pm/communication-message/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationMessage.self))
            case ("POST", "/analyst/task/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystTask.self))
            case ("POST", "/pm/delegation/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDelegationRecord.self))
            case ("POST", "/pm/delegation/launch"):
                return try makeEnvelopeResult(
                    AnalystWorkerLaunchResult(
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "exercise-task-a",
                        delegationId: spec.jsonBody?.objectValue?["delegationId"]?.stringValue ?? "delegation-1",
                        pmId: "pm-operational-exercise",
                        memoId: "memo-a",
                        memoTitle: "Scenario A Memo",
                        findingId: "finding-a",
                        findingTitle: "Exercise finding",
                        draftedSignalId: nil,
                        draftedProposalId: nil,
                        runtimeProvenance: nil,
                        summary: "Scenario A summary",
                        outputExcerpt: ""
                    )
                )
            case ("GET", "/analyst/memo?id=memo-a"):
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: "memo-a",
                        analystId: AnalystCharterSeed.analystId,
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-a",
                        delegationId: "delegation-a",
                        pmId: "pm-operational-exercise",
                        findingId: "finding-a",
                        evidenceBundleId: "bundle-a",
                        title: "Scenario A Memo",
                        executiveSummary: "AAPL still merits bounded PM attention.",
                        currentView: "Current watch read remains active.",
                        evidenceSummary: "Evidence summary A",
                        uncertaintySummary: "Uncertainty summary A",
                        recommendedNextStep: "Keep this in PM review.",
                        confidence: 0.64,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("GET", "/analyst/memo?id=memo-follow-up-1"):
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: "memo-follow-up-1",
                        analystId: AnalystCharterSeed.analystId,
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-follow-up-1",
                        delegationId: "delegation-follow-up-1",
                        pmId: "pm-operational-exercise",
                        findingId: "finding-follow-up-1",
                        evidenceBundleId: "bundle-follow-up-1",
                        title: "Follow-up Memo",
                        executiveSummary: "The challenged read remains bounded and readable.",
                        currentView: "Follow-up current view.",
                        evidenceSummary: "Follow-up evidence summary.",
                        uncertaintySummary: "Follow-up uncertainty summary.",
                        recommendedNextStep: "Keep downstream action behind the same approval gates.",
                        confidence: 0.61,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("POST", "/pm/decision/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDecisionRecord.self))
            case ("GET", "/proposals"):
                return try makeEnvelopeResult([ProposalRow]())
            case ("POST", "/proposal/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: StrategyProposal.self))
            case ("POST", "/pm/approval-request/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMApprovalRequest.self))
            case ("GET", let path) where path.hasPrefix("/pm/execution-readiness?approvalRequestId="):
                let step = await readinessCounter.next()
                let status: PMExecutionRoutingStatus = step == 0 ? .blockedMissingProposalApproval : .executableNowPaper
                let action: PMExecutionRoutingAction = step == 0 ? .submitProposalForReview : .startProposalExecution
                let summary = step == 0
                    ? "Ready to route into the proposal review path."
                    : "Ready to route through the existing paper-safe execution path."
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-1",
                        decisionId: "decision-1",
                        proposalId: "exercise-proposal-1",
                        proposalTitle: "Exercise proposal",
                        proposalStatus: step == 0 ? .draft : .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: status,
                        action: action,
                        summary: summary,
                        detail: summary,
                        blockedReasons: step == 0 ? [.proposalApprovalRequired] : []
                    )
                )
            case ("POST", "/pm/execution/route"):
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-1",
                        decisionId: "decision-1",
                        proposalId: "exercise-proposal-1",
                        proposalTitle: "Exercise proposal",
                        proposalStatus: .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: .routedSuccessfully,
                        action: .startProposalExecution,
                        summary: "Routed successfully.",
                        detail: "Routed through the existing governed path.",
                        blockedReasons: []
                    )
                )
            case ("POST", "/proposal/approve-paper"):
                return try makeEnvelopeResult(makeContractProposal(id: "exercise-proposal-1", status: .approvedPaper))
            case ("POST", "/pm/delegation/follow-up"):
                return try makeEnvelopeResult(
                    PMDelegationFollowUpResult(
                        sourceDelegationId: "exercise-delegation-a",
                        sourceFollowUpActionId: "follow-up-1",
                        createdDelegationId: "delegation-follow-up-1",
                        createdTaskId: "task-follow-up-1",
                        createdDecisionId: nil,
                        launchResult: AnalystWorkerLaunchResult(
                            charterId: AnalystCharterSeed.charterId,
                            taskId: "task-follow-up-1",
                            delegationId: "delegation-follow-up-1",
                            pmId: "pm-operational-exercise",
                            memoId: "memo-follow-up-1",
                            memoTitle: "Follow-up Memo",
                            findingId: "finding-follow-up-1",
                            findingTitle: "Follow-up Finding",
                            draftedSignalId: nil,
                            draftedProposalId: nil,
                            runtimeProvenance: nil,
                            summary: "follow-up launched",
                            outputExcerpt: ""
                        )
                    )
                )
            default:
                Issue.record("Unexpected request \(spec.method) \(spec.path)")
                return AgentControlEnvelope(ok: false, error: AgentControlErrorBody(code: "unexpected_request", message: "\(spec.method) \(spec.path)"))
            }
        },
        now: { now }
    )

    #expect(result.contextMode == PMOperationalExerciseContextMode.portfolioBacked)
    #expect(result.watchlistSymbolsUsed == ["AAPL", "MSFT", "NVDA"])
    #expect(result.scenarioResults.count == 5)
    #expect(result.scenarioResults[0].scenarioID == "scenario_a")
    #expect(result.scenarioResults[0].initiativePosture == .clarifyFirst)
    #expect(result.scenarioResults[0].actionabilityCategory == .clarification)
    #expect(result.scenarioResults[0].closureStatus == .awaitingOwner)
    #expect(result.scenarioResults[0].communicationChannel == .mockTelegram)
    #expect(result.scenarioResults[0].usedTelegramRemotePath == true)
    #expect(result.scenarioResults[0].clarificationMessageId != nil)
    #expect(result.scenarioResults[1].scenarioID == "scenario_b")
    #expect(result.scenarioResults[1].initiativePosture == .summarizeAndInform)
    #expect(result.scenarioResults[1].actionabilityCategory == .ownerInformational)
    #expect(result.scenarioResults[1].closureStatus == .closedNoFurtherAction)
    #expect(result.scenarioResults[1].strategyBriefChanged == true)
    #expect(result.scenarioResults[1].strategyBriefId == PortfolioStrategyBrief.singletonID)
    #expect(result.scenarioResults[2].scenarioID == "scenario_c")
    #expect(result.scenarioResults[2].initiativePosture == .analystBenchFirst)
    #expect(result.scenarioResults[2].actionabilityCategory == .benchInternal)
    #expect(result.scenarioResults[2].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[2].communicationChannel == .inApp)
    #expect(result.scenarioResults[2].delegationId != nil)
    #expect(result.scenarioResults[3].scenarioID == "scenario_d")
    #expect(result.scenarioResults[3].initiativePosture == .ownerDecisionRequired)
    #expect(result.scenarioResults[3].actionabilityCategory == .ownerDecisionRequired)
    #expect(result.scenarioResults[3].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[3].proposalSeeded == true)
    #expect(result.scenarioResults[3].ownerResponse == .approved)
    #expect(result.scenarioResults[3].readinessStatus == PMExecutionRoutingStatus.executableNowPaper)
    #expect(result.scenarioResults[3].routeStatus == PMExecutionRoutingStatus.routedSuccessfully)
    #expect(result.scenarioResults[3].executionPathReached == true)
    #expect(result.scenarioResults[4].scenarioID == "scenario_e")
    #expect(result.scenarioResults[4].initiativePosture == .analystBenchFirst)
    #expect(result.scenarioResults[4].actionabilityCategory == .benchInternal)
    #expect(result.scenarioResults[4].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[4].followUpDelegationId == "delegation-follow-up-1")
    let revisedBrief = await briefState.current()
    #expect(revisedBrief.updateSource == .conversationDerived)
    #expect(revisedBrief.sourceCommunicationMessageId != nil)
    let requests = await recorder.all()
    #expect(requests.contains(where: { $0.path == "/pm/portfolio-strategy-brief" }))
    #expect(requests.contains(where: { $0.path == "/pm/portfolio-strategy-brief/upsert" }))
    #expect(requests.contains(where: { $0.path == "/pm/delegation/follow-up" }))
    #expect(requests.contains(where: { $0.path == "/pm/execution/route" }))
    #expect(requests.contains(where: { $0.path == "/pm/communication-session/upsert" }))
}

@Test("pm workflow suite falls back to seeded symbols when watchlist is empty")
func pmOperationalWorkflowSuiteFallsBackToSeededContext() async throws {
    actor ReadinessCounter {
        private var value = 0
        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }
    actor WorkflowBriefState {
        private var brief: PortfolioStrategyBrief

        init(now: Date) {
            self.brief = PortfolioStrategyBrief(
                objectiveSummary: "Keep seeded exercise context bounded when watchlist state is sparse.",
                currentRiskPosture: "Moderate risk posture.",
                reviewEscalationPosture: "Escalate to PM review first.",
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: now,
                updatedAt: now
            )
        }

        func current() -> PortfolioStrategyBrief { brief }

        func update(_ updated: PortfolioStrategyBrief) -> PortfolioStrategyBrief {
            brief = updated
            return brief
        }
    }

    let now = Date(timeIntervalSince1970: 1_710_001_200)
    let readinessCounter = ReadinessCounter()
    let briefState = WorkflowBriefState(now: now)

    let result = try await AlpacaAgentCtl.runPMOperationalWorkflowSuite(
        options: PMOperationalWorkflowSuiteOptions(pmId: nil, charterId: nil),
        send: { spec in
            switch (spec.method, spec.path) {
            case ("GET", "/status"):
                return AgentControlEnvelope(ok: true, result: .object(["state": .string("ok"), "watchlist": .array([])]))
            case ("GET", "/pm/profiles"):
                return try makeEnvelopeResult([PMProfile]())
            case ("POST", "/pm/profile/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMProfile.self))
            case ("GET", "/analyst/charters"):
                return try makeEnvelopeResult([AnalystCharter]())
            case ("POST", "/analyst/charter/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystCharter.self))
            case ("GET", "/pm/portfolio-strategy-brief"):
                return try makeEnvelopeResult(await briefState.current())
            case ("POST", "/pm/portfolio-strategy-brief/upsert"):
                return try makeEnvelopeResult(await briefState.update(try decodeSpecBody(spec, as: PortfolioStrategyBrief.self)))
            case ("POST", "/pm/communication-session/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationSession.self))
            case ("POST", "/pm/communication-message/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationMessage.self))
            case ("POST", "/analyst/task/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystTask.self))
            case ("POST", "/pm/delegation/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDelegationRecord.self))
            case ("POST", "/pm/delegation/launch"):
                return try makeEnvelopeResult(
                    AnalystWorkerLaunchResult(
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-seeded",
                        delegationId: spec.jsonBody?.objectValue?["delegationId"]?.stringValue ?? "delegation-seeded",
                        pmId: "pm-operational-exercise",
                        memoId: "memo-seeded",
                        memoTitle: "Seeded Memo",
                        findingId: "finding-seeded",
                        findingTitle: "Seeded Finding",
                        draftedSignalId: nil,
                        draftedProposalId: nil,
                        runtimeProvenance: nil,
                        summary: "seeded summary",
                        outputExcerpt: ""
                    )
                )
            case ("GET", let path) where path.hasPrefix("/analyst/memo?id="):
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: path.replacingOccurrences(of: "/analyst/memo?id=", with: ""),
                        analystId: AnalystCharterSeed.analystId,
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-seeded",
                        delegationId: "delegation-seeded",
                        pmId: "pm-operational-exercise",
                        findingId: "finding-seeded",
                        evidenceBundleId: "bundle-seeded",
                        title: "Seeded Memo",
                        executiveSummary: "Seeded exercise summary.",
                        currentView: "Seeded current view.",
                        evidenceSummary: "Seeded evidence.",
                        uncertaintySummary: "Seeded uncertainty.",
                        recommendedNextStep: "Seeded next step.",
                        confidence: 0.6,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("POST", "/pm/decision/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDecisionRecord.self))
            case ("GET", "/proposals"):
                return try makeEnvelopeResult([ProposalRow]())
            case ("POST", "/proposal/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: StrategyProposal.self))
            case ("POST", "/pm/approval-request/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMApprovalRequest.self))
            case ("GET", let path) where path.hasPrefix("/pm/execution-readiness?approvalRequestId="):
                let step = await readinessCounter.next()
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-1",
                        decisionId: "decision-1",
                        proposalId: "proposal-1",
                        proposalTitle: "Seeded Proposal",
                        proposalStatus: step == 0 ? .draft : .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: step == 0 ? .blockedMissingProposalApproval : .executableNowPaper,
                        action: step == 0 ? .submitProposalForReview : .startProposalExecution,
                        summary: "seeded readiness",
                        detail: "seeded readiness",
                        blockedReasons: step == 0 ? [.proposalApprovalRequired] : []
                    )
                )
            case ("POST", "/pm/execution/route"):
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-1",
                        decisionId: "decision-1",
                        proposalId: "proposal-1",
                        proposalTitle: "Seeded Proposal",
                        proposalStatus: .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: .routedSuccessfully,
                        action: .startProposalExecution,
                        summary: "routed",
                        detail: "routed",
                        blockedReasons: []
                    )
                )
            case ("POST", "/proposal/approve-paper"):
                return try makeEnvelopeResult(makeContractProposal(id: "proposal-1", status: .approvedPaper))
            case ("POST", "/pm/delegation/follow-up"):
                return try makeEnvelopeResult(
                    PMDelegationFollowUpResult(
                        sourceDelegationId: "delegation-seeded",
                        sourceFollowUpActionId: "follow-up-seeded",
                        createdDelegationId: "delegation-seeded-follow-up",
                        createdTaskId: "task-seeded-follow-up",
                        createdDecisionId: nil,
                        launchResult: AnalystWorkerLaunchResult(
                            charterId: AnalystCharterSeed.charterId,
                            taskId: "task-seeded-follow-up",
                            delegationId: "delegation-seeded-follow-up",
                            pmId: "pm-operational-exercise",
                            memoId: "memo-seeded-follow-up",
                            memoTitle: "Seeded Follow-up",
                            findingId: "finding-seeded-follow-up",
                            findingTitle: "Seeded Follow-up Finding",
                            draftedSignalId: nil,
                            draftedProposalId: nil,
                            runtimeProvenance: nil,
                            summary: "seeded follow-up launched",
                            outputExcerpt: ""
                        )
                    )
                )
            default:
                Issue.record("Unexpected request \(spec.method) \(spec.path)")
                return AgentControlEnvelope(ok: false, error: AgentControlErrorBody(code: "unexpected_request", message: "\(spec.method) \(spec.path)"))
            }
        },
        now: { now }
    )

    #expect(result.contextMode == PMOperationalExerciseContextMode.seeded)
    #expect(result.seededSymbols == ["AAPL", "MSFT", "NVDA"])
    #expect(result.watchlistSymbolsUsed.isEmpty)
    #expect(result.scenarioResults.count == 5)
    #expect(result.scenarioResults[0].usedTelegramRemotePath == true)
    #expect(result.scenarioResults[0].initiativePosture == .clarifyFirst)
    #expect(result.scenarioResults[0].actionabilityCategory == .clarification)
    #expect(result.scenarioResults[0].closureStatus == .awaitingOwner)
    #expect(result.scenarioResults[1].strategyBriefChanged == true)
    #expect(result.scenarioResults[1].initiativePosture == .summarizeAndInform)
    #expect(result.scenarioResults[1].actionabilityCategory == .ownerInformational)
    #expect(result.scenarioResults[1].closureStatus == .closedNoFurtherAction)
    #expect(result.scenarioResults[2].symbol == "MSFT")
    #expect(result.scenarioResults[2].initiativePosture == .analystBenchFirst)
    #expect(result.scenarioResults[2].actionabilityCategory == .benchInternal)
    #expect(result.scenarioResults[2].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[3].proposalSeeded == true)
    #expect(result.scenarioResults[3].initiativePosture == .ownerDecisionRequired)
    #expect(result.scenarioResults[3].actionabilityCategory == .ownerDecisionRequired)
    #expect(result.scenarioResults[3].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[3].ownerResponse == .approved)
    #expect(result.scenarioResults[4].initiativePosture == .analystBenchFirst)
    #expect(result.scenarioResults[4].actionabilityCategory == .benchInternal)
    #expect(result.scenarioResults[4].closureStatus == .routedOrInProgress)
    #expect(result.scenarioResults[4].followUpDelegationId == "delegation-seeded-follow-up")
    let revisedBrief = await briefState.current()
    #expect(revisedBrief.updateSource == .conversationDerived)
    #expect(revisedBrief.sourceCommunicationMessageId != nil)
}

@Test("pm canonical operating suite proves compact MVP desk stories end to end")
func pmCanonicalOperatingSuiteProducesCanonicalDeskStories() async throws {
    actor RequestRecorder {
        private var values: [AgentCtlRequestSpec] = []
        func append(_ value: AgentCtlRequestSpec) { values.append(value) }
        func all() -> [AgentCtlRequestSpec] { values }
    }
    actor ReadinessCounter {
        private var value = 0
        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }
    actor BriefState {
        private var brief: PortfolioStrategyBrief

        init(now: Date) {
            self.brief = PortfolioStrategyBrief(
                objectiveSummary: "Run a calm owner desk with explicit PM escalation only when it is decision-worthy.",
                currentRiskPosture: "Moderate risk posture.",
                reviewEscalationPosture: "Escalate only after PM review is mature enough for the owner.",
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: now,
                updatedAt: now
            )
        }

        func current() -> PortfolioStrategyBrief { brief }

        func update(_ updated: PortfolioStrategyBrief) -> PortfolioStrategyBrief {
            brief = updated
            return brief
        }
    }

    let now = Date(timeIntervalSince1970: 1_710_003_000)
    let recorder = RequestRecorder()
    let readinessCounter = ReadinessCounter()
    let briefState = BriefState(now: now)

    let result = try await AlpacaAgentCtl.runPMCanonicalOperatingSuite(
        options: PMCanonicalOperatingSuiteOptions(pmId: nil, charterId: nil),
        send: { spec in
            await recorder.append(spec)
            switch (spec.method, spec.path) {
            case ("GET", "/status"):
                return AgentControlEnvelope(
                    ok: true,
                    result: .object([
                        "state": .string("ok"),
                        "watchlist": .array([.string("AAPL"), .string("MSFT"), .string("NVDA")])
                    ])
                )
            case ("GET", "/pm/profiles"):
                return try makeEnvelopeResult([PMProfile]())
            case ("POST", "/pm/profile/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMProfile.self))
            case ("GET", "/analyst/charters"):
                return try makeEnvelopeResult([AnalystCharter]())
            case ("POST", "/analyst/charter/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystCharter.self))
            case ("GET", "/pm/portfolio-strategy-brief"):
                return try makeEnvelopeResult(await briefState.current())
            case ("POST", "/pm/portfolio-strategy-brief/upsert"):
                return try makeEnvelopeResult(await briefState.update(try decodeSpecBody(spec, as: PortfolioStrategyBrief.self)))
            case ("POST", "/pm/communication-session/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationSession.self))
            case ("POST", "/pm/communication-message/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMCommunicationMessage.self))
            case ("POST", "/analyst/task/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: AnalystTask.self))
            case ("POST", "/pm/delegation/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDelegationRecord.self))
            case ("POST", "/pm/delegation/launch"):
                let delegationID = spec.jsonBody?.objectValue?["delegationId"]?.stringValue ?? "delegation-background"
                return try makeEnvelopeResult(
                    AnalystWorkerLaunchResult(
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-background",
                        delegationId: delegationID,
                        pmId: "pm-operational-exercise",
                        memoId: "memo-background",
                        memoTitle: "Background Memo",
                        findingId: "finding-background",
                        findingTitle: "Background finding",
                        draftedSignalId: nil,
                        draftedProposalId: nil,
                        runtimeProvenance: nil,
                        summary: "Background scenario summary",
                        outputExcerpt: ""
                    )
                )
            case ("GET", "/analyst/memo?id=memo-background"):
                return try makeEnvelopeResult(
                    AnalystMemo(
                        memoId: "memo-background",
                        analystId: AnalystCharterSeed.analystId,
                        charterId: AnalystCharterSeed.charterId,
                        taskId: "task-background",
                        delegationId: "memo-background-delegation",
                        pmId: "pm-operational-exercise",
                        findingId: "finding-background",
                        evidenceBundleId: "bundle-background",
                        title: "Background Memo",
                        executiveSummary: "AAPL still warrants bounded PM review, but not an owner interruption yet.",
                        currentView: "Background PM handling remains sufficient.",
                        evidenceSummary: "Evidence summary background",
                        uncertaintySummary: "Uncertainty summary background",
                        recommendedNextStep: "Keep PM and analyst review in background.",
                        confidence: 0.66,
                        runtimeProvenance: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            case ("POST", "/pm/decision/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMDecisionRecord.self))
            case ("GET", "/proposals"):
                return try makeEnvelopeResult([ProposalRow]())
            case ("POST", "/proposal/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: StrategyProposal.self))
            case ("POST", "/pm/approval-request/upsert"):
                return try makeEnvelopeResult(try decodeSpecBody(spec, as: PMApprovalRequest.self))
            case ("GET", let path) where path.hasPrefix("/pm/execution-readiness?approvalRequestId="):
                let step = await readinessCounter.next()
                let status: PMExecutionRoutingStatus = step == 0 ? .blockedMissingProposalApproval : .executableNowPaper
                let action: PMExecutionRoutingAction = step == 0 ? .submitProposalForReview : .startProposalExecution
                let summary = step == 0
                    ? "Ready to route into proposal review."
                    : "Ready to route through paper execution."
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-canonical",
                        decisionId: "decision-canonical",
                        proposalId: "proposal-canonical",
                        proposalTitle: "Canonical proposal",
                        proposalStatus: step == 0 ? .draft : .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: status,
                        action: action,
                        summary: summary,
                        detail: summary,
                        blockedReasons: step == 0 ? [.proposalApprovalRequired] : []
                    )
                )
            case ("POST", "/pm/execution/route"):
                return try makeEnvelopeResult(
                    PMExecutionRoutingAssessment(
                        approvalRequestId: "approval-canonical",
                        decisionId: "decision-canonical",
                        proposalId: "proposal-canonical",
                        proposalTitle: "Canonical proposal",
                        proposalStatus: .approvedPaper,
                        environment: .paper,
                        isLiveArmed: false,
                        killSwitchEnabled: false,
                        status: .routedSuccessfully,
                        action: .startProposalExecution,
                        summary: "Routed successfully.",
                        detail: "Routed through the existing governed path.",
                        blockedReasons: []
                    )
                )
            case ("POST", "/proposal/approve-paper"):
                return try makeEnvelopeResult(makeContractProposal(id: "proposal-canonical", status: .approvedPaper))
            case ("POST", "/pm/delegation/follow-up"):
                let request = try decodeSpecBody(spec, as: PMDelegationFollowUpRequest.self)
                return try makeEnvelopeResult(
                    PMDelegationFollowUpResult(
                        sourceDelegationId: request.sourceDelegationId,
                        sourceFollowUpActionId: "follow-up-canonical",
                        createdDelegationId: "delegation-reroute-1",
                        createdTaskId: "task-reroute-1",
                        createdDecisionId: nil,
                        launchResult: AnalystWorkerLaunchResult(
                            charterId: request.requestedCharterId ?? AnalystCharterSeed.charterId,
                            taskId: "task-reroute-1",
                            delegationId: "delegation-reroute-1",
                            pmId: "pm-operational-exercise",
                            memoId: "memo-reroute-1",
                            memoTitle: "Reroute Memo",
                            findingId: "finding-reroute-1",
                            findingTitle: "Reroute finding",
                            draftedSignalId: nil,
                            draftedProposalId: nil,
                            runtimeProvenance: nil,
                            summary: "Reroute launched",
                            outputExcerpt: ""
                        )
                    )
                )
            default:
                Issue.record("Unexpected request \(spec.method) \(spec.path)")
                return AgentControlEnvelope(
                    ok: false,
                    error: AgentControlErrorBody(code: "unexpected_request", message: "\(spec.method) \(spec.path)")
                )
            }
        },
        now: { now }
    )

    #expect(result.suiteLabel == "pm_canonical_operating_suite")
    #expect(result.contextMode == .portfolioBacked)
    #expect(result.watchlistSymbolsUsed == ["AAPL", "MSFT", "NVDA"])
    #expect(result.scenarioResults.count == 5)

    let scenariosByKind = Dictionary(uniqueKeysWithValues: result.scenarioResults.map { ($0.scenarioKind, $0) })

    let background = try #require(scenariosByKind[.backgroundHandling])
    #expect(background.initiativePosture == .analystBenchFirst)
    #expect(background.actionabilityCategory == .benchInternal)
    #expect(background.closureStatus == .routedOrInProgress)
    #expect(background.finalDeskReadinessState == .pmHandlingInBackground)
    #expect(background.ownerActionWasRequested == false)
    #expect(background.ownerActionStillPending == false)
    #expect(background.crossSurfaceMeaningAligned == true)
    #expect(background.telegramContinuationUsed == false)

    let decision = try #require(scenariosByKind[.decisionRequired])
    #expect(decision.initiativePosture == .ownerDecisionRequired)
    #expect(decision.actionabilityCategory == .ownerDecisionRequired)
    #expect(decision.closureStatus == .routedOrInProgress)
    #expect(decision.initialDeskReadinessState == .needsOwnerAttentionNow)
    #expect(decision.finalDeskReadinessState == .pmHandlingInBackground)
    #expect(decision.ownerActionWasRequested == true)
    #expect(decision.ownerActionStillPending == false)
    #expect(decision.telegramContinuationUsed == true)
    #expect(decision.ownerResponse == .approved)

    let moreWork = try #require(scenariosByKind[.moreWorkReroute])
    #expect(moreWork.initiativePosture == .analystBenchFirst)
    #expect(moreWork.actionabilityCategory == .benchInternal)
    #expect(moreWork.closureStatus == .moreWorkRequested)
    #expect(moreWork.initialDeskReadinessState == .needsOwnerAttentionNow)
    #expect(moreWork.finalDeskReadinessState == .pmHandlingInBackground)
    #expect(moreWork.ownerActionWasRequested == true)
    #expect(moreWork.ownerActionStillPending == false)
    #expect(moreWork.ownerResponse == .reviewed)
    #expect(moreWork.followUpDelegationId == "delegation-reroute-1")

    let telegram = try #require(scenariosByKind[.telegramContinuation])
    #expect(telegram.initiativePosture == .summarizeAndInform)
    #expect(telegram.actionabilityCategory == .ownerInformational)
    #expect(telegram.closureStatus == .closedNoFurtherAction)
    #expect(telegram.finalDeskReadinessState == .noImmediateActionRequired)
    #expect(telegram.telegramContinuationUsed == true)
    #expect(telegram.crossSurfaceMeaningAligned == true)

    let degraded = try #require(scenariosByKind[.runtimeDegradedFallback])
    #expect(degraded.finalDeskReadinessState == .operationalAttention)
    #expect(degraded.pmRuntimeOperabilityState == .fallbackActive)
    #expect(degraded.recentNewsRuntimeOperabilityState == .fallbackActive)
    #expect(degraded.degradedModeActive == true)
    #expect(degraded.fallbackActive == true)

    let requests = await recorder.all()
    #expect(requests.contains(where: { $0.path == "/pm/delegation/follow-up" }))
    #expect(requests.contains(where: { $0.path == "/pm/execution/route" }))
    #expect(requests.contains(where: { $0.path == "/pm/portfolio-strategy-brief/upsert" }))
    #expect(requests.contains(where: { $0.path == "/pm/communication-session/upsert" }))
}

@Test("agentctl proposal list maps to GET /proposals")
func agentctlProposalListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["proposal", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/proposals")
    #expect(request.jsonBody == nil)
}

@Test("agentctl replay quick maps to POST /replay/quick body")
func agentctlReplayQuickMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "replay", "quick",
        "--proposal", "proposal-1",
        "--symbols", "AAPL,MSFT",
        "--days", "5",
        "--timeframe", "1Min",
        "--speed", "fast",
        "--auto-ingest",
        "--feed", "iex"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/replay/quick")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["proposalId"] == .string("proposal-1"))
    #expect(object["timeframe"] == .string("1Min"))
    #expect(object["days"] == .number(5))
    #expect(object["speed"] == .string("fast"))
    #expect(object["autoIngest"] == .bool(true))
    #expect(object["feed"] == .string("iex"))
}

@Test("agentctl job list maps to GET /jobs")
func agentctlJobListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["job", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/jobs")
    #expect(request.jsonBody == nil)
}

@Test("agentctl job submit maps to POST /jobs/submit body")
func agentctlJobSubmitMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "job", "submit",
        "--type", "monitor",
        "--params", "{\"intervalSec\":2,\"maxTicks\":3}"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/jobs/submit")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["type"] == .string("monitor"))
    let params = try #require(object["params"]?.objectValue)
    #expect(params["intervalSec"] == .number(2))
    #expect(params["maxTicks"] == .number(3))
}

@Test("agentctl schedule list maps to GET /schedules")
func agentctlScheduleListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["schedule", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/schedules")
    #expect(request.jsonBody == nil)
}

@Test("agentctl schedule upsert maps to POST /schedule/upsert")
func agentctlScheduleUpsertMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "schedule", "upsert",
        "--json", "{\"scheduleId\":\"s1\",\"jobType\":\"monitor\",\"enabled\":true,\"trigger\":{\"intervalSec\":5},\"policy\":{\"runMode\":\"always_on\",\"restartOnAppLaunch\":true,\"maxRuntimeSec\":null,\"allowOverlap\":false},\"params\":{}}"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/schedule/upsert")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["scheduleId"] == .string("s1"))
    #expect(object["jobType"] == .string("monitor"))
}

@Test("agentctl schedule run-now maps to POST /schedule/run-now")
func agentctlScheduleRunNowMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["schedule", "run-now", "s-1"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/schedule/run-now")
    let body = try #require(request.jsonBody?.objectValue)
    #expect(body["id"] == .string("s-1"))
}

@Test("agentctl retention get maps to GET /retention-policy")
func agentctlRetentionGetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["retention", "get"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/retention-policy")
    #expect(request.jsonBody == nil)
}

@Test("agentctl retention set maps to POST /retention-policy/update")
func agentctlRetentionSetMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "retention", "set",
        "--json", "{\"audit\":{\"rotateWhenMB\":25,\"keepDays\":30},\"news\":{\"keepDays\":30},\"jobs\":{\"keepDaysCompleted\":14,\"keepMaxCompletedCount\":500},\"runs\":{\"enabled\":false,\"keepDays\":3650},\"barsCache\":{\"enabled\":false,\"maxDBMB\":null}}"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/retention-policy/update")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["audit"]?.objectValue?["rotateWhenMB"] == .number(25))
}

@Test("agentctl maintenance run maps to POST /maintenance/run")
func agentctlMaintenanceRunMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "maintenance", "run", "--dry-run"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/maintenance/run")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["dryRun"] == .bool(true))
}

@Test("agentctl maintenance jobs-prune defaults to dry-run and sends cutoff")
func agentctlMaintenanceJobsPruneDefaultDryRunMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "maintenance", "jobs-prune",
        "--before", "2026-04-29T00:00:00Z"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/maintenance/run")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["dryRun"] == .bool(true))
    #expect(object["jobTelemetryCleanupBefore"]?.stringValue?.hasPrefix("2026-04-29T00:00:00") == true)
}

@Test("agentctl maintenance jobs-prune apply requires explicit apply flag")
func agentctlMaintenanceJobsPruneApplyMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "maintenance", "jobs-prune",
        "--before", "2026-04-29T00:00:00Z",
        "--apply"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["dryRun"] == .bool(false))
}

@Test("agentctl maintenance memory-relief maps force diagnostics to POST /maintenance/memory-relief")
func agentctlMaintenanceMemoryReliefForceMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "maintenance", "memory-relief", "--force"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/maintenance/memory-relief")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["dryRun"] == .bool(false))
    #expect(object["force"] == .bool(true))
}

@Test("agentctl maintenance memory-relief maps dry-run diagnostics")
func agentctlMaintenanceMemoryReliefDryRunMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "maintenance", "memory-relief", "--dry-run"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    let object = try #require(request.jsonBody?.objectValue)
    #expect(request.path == "/maintenance/memory-relief")
    #expect(object["dryRun"] == .bool(true))
    #expect(object["force"] == .bool(false))
}

@Test("agentctl rss feed list maps to GET /rss/feeds")
func agentctlRSSFeedListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["rss", "feed", "list"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/rss/feeds")
    #expect(request.jsonBody == nil)
}

@Test("agentctl rss feed add maps to POST /rss/feed/add")
func agentctlRSSFeedAddMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "rss", "feed", "add",
        "--name", "Fed",
        "--url", "https://example.com/feed.xml",
        "--interval", "300",
        "--tags", "macro,rates"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/rss/feed/add")
    let object = try #require(request.jsonBody?.objectValue)
    #expect(object["name"] == .string("Fed"))
    #expect(object["url"] == .string("https://example.com/feed.xml"))
}

@Test("agentctl news list maps to GET /news")
func agentctlNewsListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "news", "list",
        "--limit", "20"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/news?limit=20")
    #expect(request.jsonBody == nil)
}

@Test("agentctl signal list maps to GET /signals")
func agentctlSignalListMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: [
        "signal", "list",
        "--status", "new",
        "--limit", "5"
    ])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "GET")
    #expect(request.path == "/signals?limit=5&status=new")
    #expect(request.jsonBody == nil)
}

@Test("agentctl signal ack maps to POST /signal/ack")
func agentctlSignalAckMapping() throws {
    let command = try AlpacaAgentCtl.parseCommand(arguments: ["signal", "ack", "sig-1"])
    let request = try AlpacaAgentCtl.requestSpec(for: command)

    #expect(request.method == "POST")
    #expect(request.path == "/signal/ack")
    let body = try #require(request.jsonBody?.objectValue)
    #expect(body["id"] == .string("sig-1"))
}

private func decodeEnvelope(_ response: IPCServerResponse) throws -> AgentControlEnvelope {
    try JSONDecoder().decode(AgentControlEnvelope.self, from: response.body)
}

func makeContractHandlers(
    startStrategy: @escaping @Sendable (String, [String: JSONValue]) async throws -> StrategyStatusSnapshot = { id, params in
        StrategyStatusSnapshot(id: id, name: id, state: .running, parameters: params)
    },
    proposal: @escaping @Sendable (String) async throws -> StrategyProposal? = { id in
        makeContractProposal(id: id)
    },
    getJob: @escaping @Sendable (String) async throws -> JobRecord = { id in
        JobRecord(
            jobId: id,
            type: .monitor,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            status: .running,
            progress: 0.5,
            message: "Running",
            parameters: ["intervalSec": .number(2)]
        )
    },
    getSchedule: @escaping @Sendable (String) async throws -> ScheduledJob? = { id in
        ScheduledJob(
            scheduleId: id,
            jobType: .monitor,
            enabled: true,
            trigger: ScheduledJobTrigger(intervalSec: 5),
            policy: ScheduledJobPolicy(
                runMode: .alwaysOn,
                restartOnAppLaunch: true,
                maxRuntimeSec: nil,
                allowOverlap: false
            ),
            params: [:]
        )
    },
    runScheduleNow: @escaping @Sendable (String) async throws -> ScheduledJobSummary = { id in
        ScheduledJobSummary(
            schedule: ScheduledJob(
                scheduleId: id,
                jobType: .monitor,
                enabled: true,
                trigger: ScheduledJobTrigger(intervalSec: 5),
                policy: ScheduledJobPolicy(
                    runMode: .alwaysOn,
                    restartOnAppLaunch: true,
                    maxRuntimeSec: nil,
                    allowOverlap: false
                ),
                params: [:],
                lastRunAt: Date(timeIntervalSince1970: 1_700_000_100),
                lastRunJobId: "job-1",
                nextRunAt: nil,
                runningJobId: "job-1"
            )
        )
    },
    getRetentionPolicy: @escaping @Sendable () async throws -> RetentionPolicy = {
        .default
    },
    updateRetentionPolicy: @escaping @Sendable (RetentionPolicy) async throws -> RetentionPolicy = { policy in
        policy.normalized()
    },
    runMaintenance: @escaping @Sendable (Bool, Date?) async throws -> JobRecord = { dryRun, cutoff in
        var parameters: [String: JSONValue] = ["dryRun": .bool(dryRun)]
        if let cutoff {
            parameters["jobTelemetryCleanupBefore"] = .string(DateCodec.formatISO8601(cutoff))
        }
        return JobRecord(
            jobId: "job-maintenance-1",
            type: .maintenanceRetention,
            createdAt: Date(timeIntervalSince1970: 1_700_000_500),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            status: .queued,
            progress: 0,
            message: "Queued",
            parameters: parameters
        )
    },
    runMemoryRelief: @escaping @Sendable (MemoryReliefRequest) async throws -> JSONValue = { request in
        .object([
            "available": .bool(true),
            "dryRun": .bool(request.dryRun),
            "force": .bool(request.force),
            "reason": .string(request.reason),
            "actionApplied": .bool(request.force && request.dryRun == false),
            "summary": .string("Memory relief contract stub.")
        ])
    },
    lastMaintenance: @escaping @Sendable () async throws -> JobSummary? = {
        JobSummary(
            jobId: "job-maintenance-1",
            type: .maintenanceRetention,
            status: .succeeded,
            createdAt: Date(timeIntervalSince1970: 1_700_000_500),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_600),
            progress: 1,
            message: "Completed",
            proposalId: nil,
            runId: nil
        )
    },
    listNews: @escaping @Sendable (Int, Date?) async throws -> [NewsEvent] = { _, _ in
        [
            NewsEvent(
                eventId: "event-1",
                source: "rss_fed",
                title: "Fed headline",
                url: "https://example.com/article",
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                receivedAt: Date(timeIntervalSince1970: 1_700_000_001),
                summary: "summary",
                rawSymbolHints: ["AAPL"],
                tags: ["macro"],
                payloadVersion: 1
            )
        ]
    },
    listPMProfiles: @escaping @Sendable () async throws -> [PMProfile] = {
        [makeContractPMProfile(id: "pm-primary")]
    },
    getPMProfile: @escaping @Sendable (String) async throws -> PMProfile = { id in
        makeContractPMProfile(id: id)
    },
    upsertPMProfile: @escaping @Sendable (PMProfile) async throws -> PMProfile = { profile in
        profile
    },
    listPMMandates: @escaping @Sendable () async throws -> [PMMandate] = {
        [makeContractPMMandate(id: "mandate-1")]
    },
    getPMMandate: @escaping @Sendable (String) async throws -> PMMandate = { id in
        makeContractPMMandate(id: id)
    },
    upsertPMMandate: @escaping @Sendable (PMMandate) async throws -> PMMandate = { mandate in
        mandate
    },
    listPMInstructions: @escaping @Sendable () async throws -> [PMInstruction] = {
        [makeContractPMInstruction(id: "instruction-1")]
    },
    getPMInstruction: @escaping @Sendable (String) async throws -> PMInstruction = { id in
        makeContractPMInstruction(id: id)
    },
    upsertPMInstruction: @escaping @Sendable (PMInstruction) async throws -> PMInstruction = { instruction in
        instruction
    },
    listPMNotebookEntries: @escaping @Sendable () async throws -> [PMNotebookEntry] = {
        [makeContractPMNotebookEntry(id: "note-1")]
    },
    getPMNotebookEntry: @escaping @Sendable (String) async throws -> PMNotebookEntry = { id in
        makeContractPMNotebookEntry(id: id)
    },
    upsertPMNotebookEntry: @escaping @Sendable (PMNotebookEntry) async throws -> PMNotebookEntry = { entry in
        entry
    },
    listPMDecisions: @escaping @Sendable () async throws -> [PMDecisionRecord] = {
        [makeContractPMDecision(id: "decision-1")]
    },
    getPMDecision: @escaping @Sendable (String) async throws -> PMDecisionRecord = { id in
        makeContractPMDecision(id: id)
    },
    upsertPMDecision: @escaping @Sendable (PMDecisionRecord) async throws -> PMDecisionRecord = { decision in
        decision
    },
    listPMApprovalRequests: @escaping @Sendable () async throws -> [PMApprovalRequest] = {
        [makeContractPMApprovalRequest(id: "approval-1")]
    },
    getPMApprovalRequest: @escaping @Sendable (String) async throws -> PMApprovalRequest = { id in
        makeContractPMApprovalRequest(id: id)
    },
    upsertPMApprovalRequest: @escaping @Sendable (PMApprovalRequest) async throws -> PMApprovalRequest = { approvalRequest in
        approvalRequest
    },
    assessPMExecutionRouting: @escaping @Sendable (String) async throws -> PMExecutionRoutingAssessment = { approvalRequestID in
        PMExecutionRoutingAssessment(
            approvalRequestId: approvalRequestID,
            decisionId: "decision-1",
            proposalId: "proposal-1",
            proposalTitle: "Heartbeat test",
            proposalStatus: .proposed,
            environment: .paper,
            isLiveArmed: false,
            killSwitchEnabled: false,
            status: .blockedMissingProposalApproval,
            action: .none,
            summary: "Waiting on proposal approval.",
            detail: "Proposal review must complete before execution routing can continue.",
            blockedReasons: [.proposalApprovalRequired]
        )
    },
    routePMExecutionApprovedIntent: @escaping @Sendable (String) async throws -> PMExecutionRoutingAssessment = { approvalRequestID in
        PMExecutionRoutingAssessment(
            approvalRequestId: approvalRequestID,
            decisionId: "decision-1",
            proposalId: "proposal-1",
            proposalTitle: "Heartbeat test",
            proposalStatus: .proposed,
            environment: .paper,
            isLiveArmed: false,
            killSwitchEnabled: false,
            status: .routedSuccessfully,
            action: .submitProposalForReview,
            summary: "Routed successfully.",
            detail: "The linked proposal was routed into the governed review path.",
            blockedReasons: []
        )
    },
    listPMCommunicationSessions: @escaping @Sendable () async throws -> [PMCommunicationSession] = {
        [makeContractPMCommunicationSession(id: "session-1")]
    },
    getPMCommunicationSession: @escaping @Sendable (String) async throws -> PMCommunicationSession = { id in
        makeContractPMCommunicationSession(id: id)
    },
    upsertPMCommunicationSession: @escaping @Sendable (PMCommunicationSession) async throws -> PMCommunicationSession = { session in
        session
    },
    listPMCommunicationMessages: @escaping @Sendable () async throws -> [PMCommunicationMessage] = {
        [makeContractPMCommunicationMessage(id: "message-1")]
    },
    getPMCommunicationMessage: @escaping @Sendable (String) async throws -> PMCommunicationMessage = { id in
        makeContractPMCommunicationMessage(id: id)
    },
    upsertPMCommunicationMessage: @escaping @Sendable (PMCommunicationMessage) async throws -> PMCommunicationMessage = { message in
        message
    },
    listPMDelegations: @escaping @Sendable () async throws -> [PMDelegationRecord] = {
        [makeContractPMDelegation(id: "delegation-1")]
    },
    getPMDelegation: @escaping @Sendable (String) async throws -> PMDelegationRecord = { id in
        makeContractPMDelegation(id: id)
    },
    upsertPMDelegation: @escaping @Sendable (PMDelegationRecord) async throws -> PMDelegationRecord = { delegation in
        delegation
    },
    submitPMDelegationFollowUp: @escaping @Sendable (PMDelegationFollowUpRequest) async throws -> PMDelegationFollowUpResult = { request in
        PMDelegationFollowUpResult(
            sourceDelegationId: request.sourceDelegationId,
            sourceFollowUpActionId: "follow-up-1",
            createdDelegationId: "delegation-follow-up-1",
            createdTaskId: "task-follow-up-1",
            createdDecisionId: nil,
            launchResult: AnalystWorkerLaunchResult(
                charterId: "charter-1",
                taskId: "task-follow-up-1",
                delegationId: "delegation-follow-up-1",
                pmId: "pm-1",
                memoId: "memo-follow-up-1",
                memoTitle: "Follow-up memo",
                findingId: "finding-follow-up-1",
                findingTitle: "Follow-up finding",
                draftedSignalId: nil,
                draftedProposalId: nil,
                runtimeProvenance: nil,
                summary: "follow-up launched",
                outputExcerpt: ""
            )
        )
    },
    launchPMDelegation: @escaping @Sendable (String, Bool, Bool) async throws -> AnalystWorkerLaunchResult = { id, draftSignal, draftProposal in
        AnalystWorkerLaunchResult(
            charterId: "charter-1",
            taskId: "task-1",
            delegationId: id,
            pmId: "pm-1",
            findingId: "finding-1",
            findingTitle: "Delegated finding",
            draftedSignalId: draftSignal ? "sig-1" : nil,
            draftedProposalId: draftProposal ? "proposal-1" : nil,
            runtimeProvenance: AnalystRuntimeProvenance(
                intendedPolicy: AnalystRuntimePolicy(
                    runtimeIdentifier: "gpt-5",
                    reasoningMode: .deliberate,
                    policySource: .pmDelegationOverride,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
                actualRuntimeIdentifier: "deterministic_local",
                launchedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            summary: "finding: Delegated finding",
            outputExcerpt: "finding_id: finding-1"
        )
    },
    listAnalystCharters: @escaping @Sendable () async throws -> [AnalystCharter] = {
        [makeContractAnalystCharter(id: "charter-1")]
    },
    getAnalystCharter: @escaping @Sendable (String) async throws -> AnalystCharter = { id in
        makeContractAnalystCharter(id: id)
    },
    upsertAnalystCharter: @escaping @Sendable (AnalystCharter) async throws -> AnalystCharter = { charter in
        charter
    },
    listAnalystTasks: @escaping @Sendable () async throws -> [AnalystTask] = {
        [makeContractAnalystTask(id: "task-1")]
    },
    getAnalystTask: @escaping @Sendable (String) async throws -> AnalystTask = { id in
        makeContractAnalystTask(id: id)
    },
    upsertAnalystTask: @escaping @Sendable (AnalystTask) async throws -> AnalystTask = { task in
        task
    },
    listAnalystFindings: @escaping @Sendable () async throws -> [AnalystFinding] = {
        [makeContractAnalystFinding(id: "finding-1")]
    },
    getAnalystFinding: @escaping @Sendable (String) async throws -> AnalystFinding = { id in
        makeContractAnalystFinding(id: id)
    },
    listAnalystMemos: @escaping @Sendable () async throws -> [AnalystMemo] = {
        [makeContractAnalystMemo(id: "memo-1")]
    },
    getAnalystMemo: @escaping @Sendable (String) async throws -> AnalystMemo = { id in
        makeContractAnalystMemo(id: id)
    },
    upsertAnalystEvidenceBundle: @escaping @Sendable (AnalystEvidenceBundle) async throws -> AnalystEvidenceBundle = { bundle in
        bundle
    },
    upsertAnalystMemo: @escaping @Sendable (AnalystMemo) async throws -> AnalystMemo = { memo in
        memo
    },
    upsertAnalystFinding: @escaping @Sendable (AnalystFinding) async throws -> AnalystFinding = { finding in
        finding
    },
    draftSignalFromAnalystFinding: @escaping @Sendable (String) async throws -> Signal = { id in
        makeContractSignal(id: "sig-\(id)")
    },
    draftProposalFromAnalystSignal: @escaping @Sendable (String, String) async throws -> StrategyProposal = { id, strategyID in
        var proposal = makeContractProposal(id: "proposal-\(id)")
        proposal.originatingSignalId = id
        proposal.strategyId = strategyID
        return proposal
    },
    getSignal: @escaping @Sendable (String) async throws -> Signal = { id in
        makeContractSignal(id: id)
    },
    replayQuick: @escaping @Sendable (ReplayQuickRequest) async throws -> ReplayRunResult = { request in
        ReplayRunResult(
            runID: "run-replay-1",
            proposalID: request.proposalID,
            barsProcessed: 1,
            barsIngested: 0,
            speed: request.speed
        )
    },
    status: @escaping @Sendable () async -> JSONValue = {
        .object(["state": .string("ok")])
    },
    armLive: @escaping @Sendable () async -> String? = { "session-1" },
    disarmLive: @escaping @Sendable () async -> Void = {},
    setKillSwitch: @escaping @Sendable (Bool) async -> Void = { _ in }
) -> AgentControlRouter.Handlers {
    AgentControlRouter.Handlers(
        status: status,
        strategies: {
            [
                StrategyStatusSnapshot(
                    id: "heartbeat",
                    name: "Heartbeat",
                    state: .stopped,
                    parameters: ["intervalSec": .number(2)]
                )
            ]
        },
        startStrategy: startStrategy,
        startStrategyFromProposal: { proposalID in
            StrategyStatusSnapshot(
                id: "heartbeat",
                name: "Heartbeat",
                state: .running,
                parameters: [:],
                proposalId: proposalID
            )
        },
        stopStrategy: { id in
            StrategyStatusSnapshot(id: id, name: id, state: .stopped)
        },
        setStrategyParams: { id, params in
            StrategyStatusSnapshot(id: id, name: id, state: .stopped, parameters: params)
        },
        proposals: {
            [
                ProposalRow(
                    id: "proposal-1",
                    title: "Heartbeat",
                    status: .proposed,
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    strategyId: "heartbeat",
                    createdBy: "agentctl"
                )
            ]
        },
        proposal: proposal,
        upsertProposal: { $0 },
        submitProposal: { id in
            makeContractProposal(id: id, status: .proposed)
        },
        approveProposalPaper: { id, reviewer, notes in
            makeContractProposal(
                id: id,
                status: .approvedPaper,
                reviewedBy: reviewer,
                reviewNotes: notes
            )
        },
        denyProposalPaper: { id, reviewer, notes in
            makeContractProposal(
                id: id,
                status: .deniedPaper,
                reviewedBy: reviewer,
                reviewNotes: notes
            )
        },
        listRuns: { _ in [] },
        getRun: { runID in
            throw PaperRunStoreError.runNotFound(id: runID)
        },
        exportRun: { runID in
            throw PaperRunStoreError.runNotFound(id: runID)
        },
        listJobs: {
            [
                JobSummary(
                    jobId: "job-1",
                    type: .monitor,
                    status: .running,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
                    progress: 0.5,
                    message: "Running",
                    proposalId: nil,
                    runId: nil
                )
            ]
        },
        getJob: getJob,
        submitJob: { type, params in
            JobRecord(
                jobId: "job-submitted-1",
                type: type,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                status: .queued,
                progress: 0,
                message: "Queued",
                parameters: params
            )
        },
        cancelJob: { id in
            JobRecord(
                jobId: id,
                type: .monitor,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_010),
                status: .canceled,
                progress: 0.3,
                message: "Canceled",
                parameters: [:],
                error: JobErrorInfo(code: "job_canceled", message: "Job canceled by user.")
            )
        },
        listSchedules: {
            [
                ScheduledJobSummary(
                    schedule: ScheduledJob(
                        scheduleId: "schedule-1",
                        jobType: .monitor,
                        enabled: true,
                        trigger: ScheduledJobTrigger(intervalSec: 5),
                        policy: ScheduledJobPolicy(
                            runMode: .alwaysOn,
                            restartOnAppLaunch: true,
                            maxRuntimeSec: nil,
                            allowOverlap: false
                        ),
                        params: [:]
                    )
                )
            ]
        },
        getSchedule: getSchedule,
        upsertSchedule: { schedule in
            ScheduledJobSummary(schedule: schedule)
        },
        removeSchedule: { id in
            if id == "missing" {
                throw ScheduleStoreError.scheduleNotFound(id: id)
            }
        },
        setScheduleEnabled: { id, enabled in
            ScheduledJobSummary(
                schedule: ScheduledJob(
                    scheduleId: id,
                    jobType: .monitor,
                    enabled: enabled,
                    trigger: ScheduledJobTrigger(intervalSec: 5),
                    policy: ScheduledJobPolicy(
                        runMode: .alwaysOn,
                        restartOnAppLaunch: true,
                        maxRuntimeSec: nil,
                        allowOverlap: false
                    ),
                    params: [:]
                )
            )
        },
        runScheduleNow: runScheduleNow,
        getRetentionPolicy: getRetentionPolicy,
        updateRetentionPolicy: updateRetentionPolicy,
        runMaintenance: runMaintenance,
        runMemoryRelief: runMemoryRelief,
        lastMaintenance: lastMaintenance,
        listRSSFeeds: {
            [
                RSSFeed(
                    id: "feed-1",
                    name: "Fed",
                    url: "https://example.com/fed.xml",
                    enabled: true,
                    pollIntervalSec: 300,
                    tags: ["macro"]
                )
            ]
        },
        addRSSFeed: { feed in
            feed
        },
        updateRSSFeed: { feed in
            feed
        },
        removeRSSFeed: { _ in },
        listNews: listNews,
        listPMProfiles: listPMProfiles,
        getPMProfile: getPMProfile,
        upsertPMProfile: upsertPMProfile,
        listPMMandates: listPMMandates,
        getPMMandate: getPMMandate,
        upsertPMMandate: upsertPMMandate,
        listPMInstructions: listPMInstructions,
        getPMInstruction: getPMInstruction,
        upsertPMInstruction: upsertPMInstruction,
        listPMNotebookEntries: listPMNotebookEntries,
        getPMNotebookEntry: getPMNotebookEntry,
        upsertPMNotebookEntry: upsertPMNotebookEntry,
        getPortfolioStrategyBrief: {
            PortfolioStrategyBrief(
                objectiveSummary: "Keep event-aware exposure bounded.",
                currentRiskPosture: "Moderate risk posture.",
                reviewEscalationPosture: "Escalate to PM review first.",
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        },
        upsertPortfolioStrategyBrief: { brief in
            brief
        },
        getRecentNewsAnalystRuntimeSettings: {
            RecentNewsAnalystRuntimeSettings(
                model: .gpt41Mini,
                reasoningMode: .standard,
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        },
        upsertRecentNewsAnalystRuntimeSettings: { settings in
            settings
        },
        getStandingBenchAnalystRuntimeSettings: {
            StandingBenchAnalystRuntimeSettings(
                runtimeIdentifier: "gpt-4.1",
                reasoningMode: .standard,
                updatedBy: "pm-primary",
                updateSource: .pmControlPlane,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        },
        upsertStandingBenchAnalystRuntimeSettings: { settings in
            settings
        },
        listPMDecisions: listPMDecisions,
        getPMDecision: getPMDecision,
        upsertPMDecision: upsertPMDecision,
        listPMApprovalRequests: listPMApprovalRequests,
        getPMApprovalRequest: getPMApprovalRequest,
        upsertPMApprovalRequest: upsertPMApprovalRequest,
        assessPMExecutionRouting: assessPMExecutionRouting,
        routePMExecutionApprovedIntent: routePMExecutionApprovedIntent,
        listPMCommunicationSessions: listPMCommunicationSessions,
        getPMCommunicationSession: getPMCommunicationSession,
        upsertPMCommunicationSession: upsertPMCommunicationSession,
        listPMCommunicationMessages: listPMCommunicationMessages,
        getPMCommunicationMessage: getPMCommunicationMessage,
        upsertPMCommunicationMessage: upsertPMCommunicationMessage,
        listPMDelegations: listPMDelegations,
        getPMDelegation: getPMDelegation,
        upsertPMDelegation: upsertPMDelegation,
        submitPMDelegationFollowUp: submitPMDelegationFollowUp,
        launchPMDelegation: launchPMDelegation,
        listAnalystCharters: listAnalystCharters,
        getAnalystCharter: getAnalystCharter,
        upsertAnalystCharter: upsertAnalystCharter,
        listAnalystTasks: listAnalystTasks,
        getAnalystTask: getAnalystTask,
        upsertAnalystTask: upsertAnalystTask,
        listAnalystFindings: listAnalystFindings,
        getAnalystFinding: getAnalystFinding,
        listAnalystMemos: listAnalystMemos,
        getAnalystMemo: getAnalystMemo,
        upsertAnalystEvidenceBundle: upsertAnalystEvidenceBundle,
        upsertAnalystMemo: upsertAnalystMemo,
        upsertAnalystFinding: upsertAnalystFinding,
        draftSignalFromAnalystFinding: draftSignalFromAnalystFinding,
        draftProposalFromAnalystSignal: draftProposalFromAnalystSignal,
        listSignals: { _, _ in
            [
                makeContractSignal(id: "sig-1")
            ]
        },
        getSignal: getSignal,
        acknowledgeSignal: { id in
            var signal = try await getSignal(id)
            signal.status = .acknowledged
            return signal
        },
        archiveSignal: { id in
            var signal = try await getSignal(id)
            signal.status = .archived
            return signal
        },
        replayIngest: { request in
            ReplayIngestResult(
                symbols: request.symbols,
                timeframe: request.timeframe,
                start: request.start,
                end: request.end,
                feed: request.feed,
                barsIngested: 1
            )
        },
        replayRun: { request in
            ReplayRunResult(
                runID: "run-replay-1",
                proposalID: request.proposalID,
                barsProcessed: 1,
                barsIngested: 0,
                speed: request.speed,
                simulateTrades: request.simulateTrades,
                fillPolicy: request.fillPolicy,
                slippageBps: request.slippageBps
            )
        },
        replayQuick: replayQuick,
        armLive: armLive,
        disarmLive: disarmLive,
        setKillSwitch: setKillSwitch
    )
}

private actor IPCCallRecorder {
    private var count = 0

    func record() {
        count += 1
    }

    func callCount() -> Int {
        count
    }
}

private actor IPCBoolRecorder {
    private var recordedValues: [Bool] = []

    func record(_ value: Bool) {
        recordedValues.append(value)
    }

    func values() -> [Bool] {
        recordedValues
    }
}

private func makeContractProposal(
    id: String,
    status: StrategyProposalStatus = .draft,
    reviewedBy: String? = nil,
    reviewNotes: String? = nil
) -> StrategyProposal {
    StrategyProposal(
        proposalId: id,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        createdBy: "agentctl",
        title: "Heartbeat test",
        summary: "Contract test proposal",
        strategyId: "heartbeat",
        parameters: ["intervalSec": .number(2)],
        scope: StrategyProposalScope(symbols: ["FAKEPACA"], watchlistReference: nil),
        intendedEnvironmentPaperOnly: true,
        constraints: StrategyProposalConstraints(
            maxOrdersPerMinute: 5,
            maxNotionalPerOrder: Decimal(1000)
        ),
        testPlan: StrategyProposalTestPlan(
            durationMinutes: 5,
            successMetrics: ["stays_running"],
            stopConditions: ["manual_stop"]
        ),
        rationale: "Contract test fixture",
        approval: StrategyProposalApproval(
            status: status,
            reviewedBy: reviewedBy,
            reviewedAt: reviewedBy == nil ? nil : Date(timeIntervalSince1970: 1_700_000_100),
            reviewNotes: reviewNotes
        )
    )
}

private func makeContractPMProfile(id: String) -> PMProfile {
    PMProfile(
        pmId: id,
        displayName: "Primary PM",
        roleSummary: "Owns durable mandate, standing instructions, and supervisory memory.",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMMandate(id: String) -> PMMandate {
    PMMandate(
        mandateId: id,
        pmId: "pm-primary",
        title: "Core PM Mandate",
        objectiveSummary: "Compound capital while preserving explicit approval discipline.",
        scope: "Cross-asset supervisory portfolio management.",
        constraints: ["No autonomous live trading"],
        riskBoundaries: ["Respect paper/live posture"],
        successCriteria: ["Traceable decisions"],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMInstruction(id: String) -> PMInstruction {
    PMInstruction(
        instructionId: id,
        pmId: "pm-primary",
        title: "Standing guidance",
        body: "Prefer durable app-owned records over transcript memory.",
        category: "operating_guidance",
        status: .active,
        effectiveAt: Date(timeIntervalSince1970: 1_700_000_050),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMNotebookEntry(id: String) -> PMNotebookEntry {
    PMNotebookEntry(
        entryId: id,
        pmId: "pm-primary",
        title: "Working note",
        body: "Promote remote conversation outcomes selectively into durable PM memory.",
        tags: ["memory", "pm"],
        sourceSummary: "owner guidance",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeEnvelopeResult<T: Encodable>(_ value: T) throws -> AgentControlEnvelope {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = DateCodec.iso8601EncodingStrategy
    let data = try encoder.encode(value)
    let jsonValue = try JSONDecoder().decode(JSONValue.self, from: data)
    return AgentControlEnvelope(ok: true, result: jsonValue)
}

private func decodeSpecBody<T: Decodable>(_ spec: AgentCtlRequestSpec, as type: T.Type) throws -> T {
    guard let jsonBody = spec.jsonBody else {
        throw NSError(domain: "IPCContractTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing JSON body"])
    }
    let encoder = JSONEncoder()
    let data = try encoder.encode(jsonBody)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = DateCodec.iso8601DecodingStrategy
    return try decoder.decode(type, from: data)
}

private func makeContractPMDecision(id: String) -> PMDecisionRecord {
    PMDecisionRecord(
        decisionId: id,
        pmId: "pm-primary",
        title: "Recommend bounded review",
        summary: "PM recommends a bounded decision record linked to analyst outputs.",
        decisionType: .recommendation,
        status: .active,
        delegationId: "delegation-1",
        charterId: "charter-1",
        taskId: "task-1",
        findingId: "finding-1",
        signalId: "sig-1",
        proposalId: "proposal-1",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMApprovalRequest(id: String) -> PMApprovalRequest {
    PMApprovalRequest(
        approvalRequestId: id,
        pmId: "pm-primary",
        subject: "Request bounded human review",
        rationale: "PM wants an app-owned approval-ready record distinct from proposal approval state.",
        requestType: .proposalReview,
        status: .pending,
        decisionId: "decision-1",
        delegationId: "delegation-1",
        findingId: "finding-1",
        signalId: "sig-1",
        proposalId: "proposal-1",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMCommunicationSession(id: String) -> PMCommunicationSession {
    PMCommunicationSession(
        sessionId: id,
        channel: .mockTelegram,
        externalConversationId: "chat-1",
        pmId: "pm-primary",
        participantId: "owner-1",
        participantDisplayName: "Owner",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMCommunicationMessage(id: String) -> PMCommunicationMessage {
    PMCommunicationMessage(
        messageId: id,
        sessionId: "session-1",
        direction: .incoming,
        senderRole: .owner,
        senderId: "owner-1",
        body: "Please promote this into a durable PM record if it matters.",
        sentAt: Date(timeIntervalSince1970: 1_700_000_050),
        promotion: PMCommunicationPromotion(
            targetType: .decision,
            targetId: "decision-1",
            promotedAt: Date(timeIntervalSince1970: 1_700_000_100)
        ),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractPMDelegation(id: String) -> PMDelegationRecord {
    PMDelegationRecord(
        delegationId: id,
        pmId: "pm-primary",
        analystId: "macro-analyst",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Validate technology adoption thesis",
        rationale: "PM wants a bounded charter-scoped research pass tied to the current portfolio mandate.",
        requestedOutputs: [.finding, .signal],
        status: .issued,
        runtimePolicyOverride: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5",
            reasoningMode: .deliberate,
            policySource: .pmDelegationOverride,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        ),
        linkedFindingIDs: [],
        linkedSignalIDs: [],
        linkedProposalIDs: [],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractAnalystCharter(id: String) -> AnalystCharter {
    AnalystCharter(
        charterId: id,
        analystId: "macro-analyst",
        title: "Macro Charter",
        coverageScope: "US macro and mega-cap equities",
        strategyFamily: "news-driven swing",
        summary: "Track macro catalysts and evidence-backed implications",
        duties: ["Track app news"],
        constraints: ["No trade approval"],
        expectedOutputs: ["finding", "signal"],
        allowedSources: ["app_news", "web"],
        defaultRuntimePolicy: AnalystRuntimePolicy(
            runtimeIdentifier: "gpt-5-mini",
            reasoningMode: .standard,
            policySource: .charterDefault,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        ),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractAnalystTask(id: String) -> AnalystTask {
    AnalystTask(
        taskId: id,
        analystId: "macro-analyst",
        charterId: "charter-1",
        title: "Review macro catalysts",
        description: "Summarize evidence-backed implications.",
        status: .inProgress,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_050),
        symbols: ["AAPL"],
        tags: ["macro"],
        lastCheckpointSummary: "Collected recent news",
        checkpoint: AnalystTaskCheckpoint(
            checkpointID: "checkpoint-\(id)",
            taskId: id,
            analystId: "macro-analyst",
            charterId: "charter-1",
            summary: "Collected recent news",
            nextPlannedAction: "Review disconfirming evidence",
            openQuestions: ["What changes the macro view?"],
            linkedFindingIDs: ["finding-1"],
            linkedEvidenceBundleIDs: ["bundle-1"],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_050)
        ),
        linkedFindingIDs: ["finding-1"]
    )
}

private func makeContractAnalystFinding(id: String) -> AnalystFinding {
    AnalystFinding(
        findingId: id,
        analystId: "macro-analyst",
        charterId: "charter-1",
        taskId: "task-1",
        title: "Rates pressure easing",
        summary: "Cross-source evidence suggests easing macro pressure.",
        thesis: "Large-cap tech may benefit if the trend persists.",
        symbols: ["AAPL"],
        tags: ["macro"],
        status: .open,
        confidence: 0.71,
        timeHorizon: "swing",
        evidenceBundleId: "bundle-1",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractAnalystMemo(id: String) -> AnalystMemo {
    AnalystMemo(
        memoId: id,
        analystId: "macro-analyst",
        charterId: "charter-1",
        taskId: "task-1",
        delegationId: "delegation-1",
        pmId: "pm-1",
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        title: "Rates pressure easing",
        executiveSummary: "Macro pressure appears to be easing, which supports a more constructive near-term view for large-cap tech.",
        currentView: "The analyst view remains constructive but bounded by timing uncertainty.",
        evidenceSummary: "This memo draws on recent app-owned macro headlines plus supporting cross-source context.",
        uncertaintySummary: "Further evidence is needed to confirm that the shift is durable rather than a short-lived tone change.",
        recommendedNextStep: "Use this memo as readable PM support and monitor the next evidence cycle before escalating further.",
        confidence: 0.71,
        runtimeProvenance: AnalystRuntimeProvenance(
            intendedPolicy: AnalystRuntimePolicy(
                runtimeIdentifier: "gpt-5-mini",
                reasoningMode: .standard,
                policySource: .charterDefault,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            ),
            actualRuntimeIdentifier: "deterministic_local",
            actualReasoningMode: nil,
            launchedAt: Date(timeIntervalSince1970: 1_700_000_100)
        ),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
}

private func makeContractSignal(id: String) -> Signal {
    let findingID = id.replacingOccurrences(of: "sig-", with: "")
    return Signal(
        signalId: id,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        status: .new,
        symbols: ["AAPL"],
        direction: .bullish,
        horizon: .swing,
        confidence: 0.71,
        score: 0.71,
        positionStatement: "Large-cap tech may benefit if the trend persists.",
        recommendedAction: .notifyOnly,
        evidence: [
            SignalEvidenceRef(
                type: .finding,
                id: findingID,
                url: nil,
                title: "Rates pressure easing",
                summary: "Cross-source evidence suggests easing macro pressure.",
                timestamp: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ],
        provenance: SignalProvenance(
            sourceJobId: "analyst.finding_draft",
            scoringVersion: "analyst-finding-v1",
            analystId: "macro-analyst",
            charterId: "charter-1",
            taskId: "task-1",
            sourceFindingId: findingID,
            sourceEvidenceBundleId: "bundle-1"
        ),
        originatingFindingId: findingID
    )
}

private func loadIPCDocs(filePath: String = #filePath) throws -> String {
    let fileURL = URL(fileURLWithPath: filePath)
    let repositoryRoot = fileURL
        .deletingLastPathComponent() // TradingKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // TradingKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
    let docsURL = repositoryRoot
        .appendingPathComponent("docs", isDirectory: true)
        .appendingPathComponent("IPC.md", isDirectory: false)

    return try String(contentsOf: docsURL, encoding: .utf8)
}
