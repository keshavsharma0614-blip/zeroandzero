import Foundation
import XCTest
@testable import TradingKit

final class IPCNetworkIntegrationTests: XCTestCase {
    func testLoopbackServerServesStatus() async throws {
        let token = "token-123"
        let router = AgentControlRouter(authToken: token, handlers: makeContractHandlers())
        let server = LoopbackHTTPServer()
        let port = try await server.start(host: "127.0.0.1", preferredPort: 0) { request in
            await router.handle(request)
        }

        let runtimeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TradingKitTests-ipc-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
        let runtimeStore = AgentControlRuntimeInfoStore(
            fileURL: runtimeRoot.appendingPathComponent("ipc.json", isDirectory: false)
        )
        try runtimeStore.save(
            AgentControlRuntimeInfo(host: "127.0.0.1", port: port, token: token)
        )
        let runtimeInfo = try runtimeStore.load()

        do {
            let url = try requireURL("http://\(runtimeInfo.host):\(runtimeInfo.port)/status")
            var request = URLRequest(url: url)
            request.setValue(runtimeInfo.token, forHTTPHeaderField: "X-Agent-Token")
            let session = URLSession(configuration: .ephemeral)
            defer {
                session.finishTasksAndInvalidate()
            }
            let (data, response) = try await session.data(for: request)
            let http = try requireHTTPURLResponse(response)
            let envelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: data)

            XCTAssertEqual(http.statusCode, 200)
            XCTAssertEqual(envelope.ok, true)
        } catch {
            await stopServerAndDrain(server)
            throw error
        }

        await stopServerAndDrain(server)
    }

    func testLoopbackServerRejectsWrongToken() async throws {
        let router = AgentControlRouter(authToken: "token-123", handlers: makeContractHandlers())
        let server = LoopbackHTTPServer()
        let port = try await server.start(host: "127.0.0.1", preferredPort: 0) { request in
            await router.handle(request)
        }

        do {
            let url = try requireURL("http://127.0.0.1:\(port)/status")
            var request = URLRequest(url: url)
            request.setValue("wrong-token", forHTTPHeaderField: "X-Agent-Token")
            let session = URLSession(configuration: .ephemeral)
            defer {
                session.finishTasksAndInvalidate()
            }
            let (data, response) = try await session.data(for: request)
            let http = try requireHTTPURLResponse(response)
            let envelope = try JSONDecoder().decode(AgentControlEnvelope.self, from: data)

            XCTAssertEqual(http.statusCode, 401)
            XCTAssertEqual(envelope.ok, false)
            XCTAssertEqual(envelope.error?.code, "unauthorized")
        } catch {
            await stopServerAndDrain(server)
            throw error
        }

        await stopServerAndDrain(server)
    }

    func testLoopbackServerFallsBackWhenPreferredInUse() async throws {
        let routerA = AgentControlRouter(authToken: "token-a", handlers: makeContractHandlers())
        let routerB = AgentControlRouter(authToken: "token-b", handlers: makeContractHandlers())

        let serverA = LoopbackHTTPServer()
        let firstPort = try await serverA.start(host: "127.0.0.1", preferredPort: 0) { request in
            await routerA.handle(request)
        }
        XCTAssertGreaterThan(firstPort, 0)

        let serverB = LoopbackHTTPServer()
        do {
            let secondPort = try await serverB.start(host: "127.0.0.1", preferredPort: UInt16(firstPort)) { request in
                await routerB.handle(request)
            }
            XCTAssertGreaterThan(secondPort, 0)
            XCTAssertNotEqual(secondPort, firstPort)
        } catch {
            await stopServerAndDrain(serverB)
            await stopServerAndDrain(serverA)
            throw error
        }

        await stopServerAndDrain(serverB)
        await stopServerAndDrain(serverA)
    }

    func testAnalystIPCClientReportsMissingRuntimeMetadata() async throws {
        let runtimeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TradingKitTests-ipc-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
        let runtimeStore = AgentControlRuntimeInfoStore(
            fileURL: runtimeRoot.appendingPathComponent("ipc.json", isDirectory: false)
        )
        let client = AnalystIPCClient(
            runtimeInfoStore: runtimeStore,
            session: URLSession(configuration: .ephemeral)
        )

        do {
            _ = try await client.listCharters()
            XCTFail("Expected missing runtime metadata")
        } catch AgentControlRuntimeInfoStoreError.missingFile {
            // Expected.
        }
    }

    func testAnalystIPCClientReportsUnauthorizedWithoutTokenLeak() async throws {
        let router = AgentControlRouter(authToken: "expected-token", handlers: makeContractHandlers())
        let server = LoopbackHTTPServer()
        let port = try await server.start(host: "127.0.0.1", preferredPort: 0) { request in
            await router.handle(request)
        }
        let runtimeStore = try makeRuntimeInfoStore(
            name: "ipc-unauthorized",
            port: port,
            token: "wrong-token"
        )
        let session = URLSession(configuration: .ephemeral)
        let client = AnalystIPCClient(runtimeInfoStore: runtimeStore, session: session)

        do {
            _ = try await client.listCharters()
            XCTFail("Expected unauthorized IPC response")
        } catch let error as AnalystIPCClientError {
            guard case let .unauthorized(host, reportedPort, tokenPresent, metadataSource) = error else {
                XCTFail("Expected unauthorized, got \(error)")
                await stopServerAndDrain(server)
                session.finishTasksAndInvalidate()
                return
            }
            XCTAssertEqual(host, "127.0.0.1")
            XCTAssertEqual(reportedPort, port)
            XCTAssertTrue(tokenPresent)
            XCTAssertEqual(metadataSource, "ipc.json")
        } catch {
            await stopServerAndDrain(server)
            session.finishTasksAndInvalidate()
            throw error
        }

        session.finishTasksAndInvalidate()
        await stopServerAndDrain(server)
    }

    func testAnalystIPCClientReportsConnectionRefusedForStaleRuntimeMetadata() async throws {
        let stalePort = try await reserveEphemeralPort()
        let runtimeStore = try makeRuntimeInfoStore(
            name: "ipc-stale",
            port: stalePort,
            token: "token-stale"
        )
        let session = URLSession(configuration: .ephemeral)
        let client = AnalystIPCClient(runtimeInfoStore: runtimeStore, session: session)

        do {
            _ = try await client.listCharters()
            XCTFail("Expected stale metadata transport failure")
        } catch let error as AnalystIPCClientError {
            guard case let .transport(category, host, port, tokenPresent, metadataSource, attempts) = error else {
                XCTFail("Expected transport, got \(error)")
                session.finishTasksAndInvalidate()
                return
            }
            XCTAssertEqual(category, "connection_refused")
            XCTAssertEqual(host, "127.0.0.1")
            XCTAssertEqual(port, stalePort)
            XCTAssertTrue(tokenPresent)
            XCTAssertEqual(metadataSource, "ipc.json")
            XCTAssertEqual(attempts, 4)
        } catch {
            session.finishTasksAndInvalidate()
            throw error
        }

        session.finishTasksAndInvalidate()
    }

    func testAnalystIPCClientRetrySucceedsWhenRuntimePortBecomesAvailable() async throws {
        let delayedPort = try await reserveEphemeralPort()
        let runtimeStore = try makeRuntimeInfoStore(
            name: "ipc-delayed",
            port: delayedPort,
            token: "token-delayed"
        )
        let router = AgentControlRouter(authToken: "token-delayed", handlers: makeContractHandlers())
        let delayedServer = LoopbackHTTPServer()
        let serverTask = Task {
            try await Task.sleep(nanoseconds: 180_000_000)
            _ = try await delayedServer.start(host: "127.0.0.1", preferredPort: UInt16(delayedPort)) { request in
                await router.handle(request)
            }
        }
        let session = URLSession(configuration: .ephemeral)
        let client = AnalystIPCClient(runtimeInfoStore: runtimeStore, session: session)

        do {
            let charters = try await client.listCharters()
            XCTAssertFalse(charters.isEmpty)
            try await serverTask.value
        } catch {
            serverTask.cancel()
            await stopServerAndDrain(delayedServer)
            session.finishTasksAndInvalidate()
            throw error
        }

        session.finishTasksAndInvalidate()
        await stopServerAndDrain(delayedServer)
    }

    private func requireURL(_ raw: String) throws -> URL {
        if let value = URL(string: raw) {
            return value
        }
        XCTFail("Expected valid URL: \(raw)")
        throw NSError(domain: "IPCNetworkIntegrationTests", code: 1)
    }

    private func requireHTTPURLResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        if let value = response as? HTTPURLResponse {
            return value
        }
        XCTFail("Expected HTTPURLResponse")
        throw NSError(domain: "IPCNetworkIntegrationTests", code: 2)
    }

    private func makeRuntimeInfoStore(name: String, port: Int, token: String) throws -> AgentControlRuntimeInfoStore {
        let runtimeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeRoot, withIntermediateDirectories: true)
        let runtimeStore = AgentControlRuntimeInfoStore(
            fileURL: runtimeRoot.appendingPathComponent("ipc.json", isDirectory: false)
        )
        try runtimeStore.save(
            AgentControlRuntimeInfo(host: "127.0.0.1", port: port, token: token)
        )
        return runtimeStore
    }

    private func reserveEphemeralPort() async throws -> Int {
        let server = LoopbackHTTPServer()
        let port = try await server.start(host: "127.0.0.1", preferredPort: 0) { _ in
            IPCServerResponse(statusCode: 503, body: Data())
        }
        await stopServerAndDrain(server)
        return port
    }
}

private func stopServerAndDrain(_ server: LoopbackHTTPServer) async {
    await server.stop()
    try? await Task.sleep(nanoseconds: 20_000_000)
}
