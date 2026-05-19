import Foundation
import Network

private final class ListenerStartGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int?, Error>?
    private var hasResumed = false

    init(continuation: CheckedContinuation<Int?, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Int?) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed, let continuation else {
            return
        }
        hasResumed = true
        self.continuation = nil
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed, let continuation else {
            return
        }
        hasResumed = true
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}

public actor LoopbackHTTPServer {
    public enum ServerError: Error {
        case failedToBind
        case notRunning
        case invalidResolvedPort
    }

    private let queue = DispatchQueue(label: "TradingKit.LoopbackHTTPServer")
    private var listener: NWListener?
    private var requestHandler: (@Sendable (IPCServerRequest) async -> IPCServerResponse)?
    private var activeConnections: [UUID: NWConnection] = [:]

    public init() {}

    deinit {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        requestHandler = nil

        let connections = activeConnections
        activeConnections.removeAll()
        for connection in connections.values {
            connection.cancel()
        }
    }

    @discardableResult
    public func start(
        host: String = "127.0.0.1",
        preferredPort: UInt16 = 8765,
        requestHandler: @escaping @Sendable (IPCServerRequest) async -> IPCServerResponse
    ) async throws -> Int {
        self.requestHandler = requestHandler
        if preferredPort == 0 {
            guard let ephemeral = try? await tryStartListener(host: host, port: 0) else {
                throw ServerError.failedToBind
            }
            return ephemeral
        }

        if let preferred = try? await tryStartListener(host: host, port: preferredPort) {
            return preferred
        }

        // Fallback to an ephemeral port if preferred port is unavailable.
        guard let fallback = try? await tryStartListener(host: host, port: 0) else {
            throw ServerError.failedToBind
        }
        return fallback
    }

    public func stop() async {
        if let listener {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
        }
        listener = nil
        requestHandler = nil

        let connections = activeConnections
        activeConnections.removeAll()
        for connection in connections.values {
            connection.cancel()
        }
    }

    public func listeningPort() -> Int? {
        guard let raw = listener?.port?.rawValue, raw > 0 else {
            return nil
        }
        return Int(raw)
    }

    private func tryStartListener(host: String, port: UInt16) async throws -> Int {
        let hostValue = NWEndpoint.Host(host)
        let portValue = NWEndpoint.Port(rawValue: port) ?? .any

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: hostValue, port: portValue)

        let listener = try NWListener(using: parameters)

        let resolvedPort: Int?
        do {
            resolvedPort = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int?, Error>) in
                let gate = ListenerStartGate(continuation: continuation)

                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let rawPort = listener.port?.rawValue ?? 0
                        gate.resume(returning: Int(rawPort))
                    case .failed(let error):
                        gate.resume(throwing: error)
                    case .cancelled:
                        gate.resume(throwing: ServerError.notRunning)
                    default:
                        break
                    }
                }

                listener.newConnectionHandler = { [weak self] connection in
                    Task {
                        await self?.accept(connection)
                    }
                }

                listener.start(queue: queue)
            }
        } catch {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
            throw error
        }

        guard let resolvedPort, resolvedPort > 0 else {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
            throw ServerError.invalidResolvedPort
        }

        self.listener = listener
        return resolvedPort
    }

    private func accept(_ connection: NWConnection) async {
        let id = UUID()
        activeConnections[id] = connection

        connection.start(queue: queue)
        receiveRequest(on: connection, connectionID: id, accumulated: Data())
    }

    private nonisolated func receiveRequest(
        on connection: NWConnection,
        connectionID: UUID,
        accumulated: Data
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if let request = Self.parseHTTPRequest(buffer) {
                Task {
                    await self.handleParsedRequest(request, connection: connection, connectionID: connectionID)
                }
                return
            }

            if isComplete || error != nil {
                Task {
                    let body = Data("{\"ok\":false,\"error\":{\"code\":\"bad_request\",\"message\":\"Incomplete or invalid HTTP request\"}}".utf8)
                    await self.sendResponse(
                        IPCServerResponse(statusCode: 400, body: body),
                        on: connection,
                        connectionID: connectionID
                    )
                }
                return
            }

            self.receiveRequest(on: connection, connectionID: connectionID, accumulated: buffer)
        }
    }

    private func handleParsedRequest(
        _ request: IPCServerRequest,
        connection: NWConnection,
        connectionID: UUID
    ) async {
        guard let requestHandler else {
            let body = Data("{\"ok\":false,\"error\":{\"code\":\"server_not_running\",\"message\":\"IPC server not running\"}}".utf8)
            await sendResponse(
                IPCServerResponse(statusCode: 503, body: body),
                on: connection,
                connectionID: connectionID
            )
            return
        }

        let response = await requestHandler(request)
        await sendResponse(response, on: connection, connectionID: connectionID)
    }

    private func sendResponse(
        _ response: IPCServerResponse,
        on connection: NWConnection,
        connectionID: UUID
    ) async {
        let statusMessage = Self.statusMessage(response.statusCode)
        var payload = Data()
        payload.append(Data("HTTP/1.1 \(response.statusCode) \(statusMessage)\r\n".utf8))
        payload.append(Data("Content-Type: application/json\r\n".utf8))
        payload.append(Data("Content-Length: \(response.body.count)\r\n".utf8))
        payload.append(Data("Connection: close\r\n\r\n".utf8))
        payload.append(response.body)

        connection.send(content: payload, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            Task {
                await self?.closeConnection(connectionID)
            }
        })
    }

    private func closeConnection(_ id: UUID) {
        activeConnections[id] = nil
    }

    private static func parseHTTPRequest(_ data: Data) -> IPCServerRequest? {
        let separator = Data([0x0d, 0x0a, 0x0d, 0x0a])
        guard let headerBoundary = data.range(of: separator) else {
            return nil
        }

        let headerData = data.subdata(in: data.startIndex..<headerBoundary.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        let headerLines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else {
            return nil
        }

        let requestLineParts = requestLine.split(separator: " ")
        guard requestLineParts.count >= 2 else {
            return nil
        }

        let method = String(requestLineParts[0]).uppercased()
        let path = String(requestLineParts[1])

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else {
                continue
            }
            let key = line[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerBoundary.upperBound

        guard data.count >= bodyStart + contentLength else {
            return nil
        }

        let bodyRange = bodyStart..<(bodyStart + contentLength)
        let body = contentLength > 0 ? data.subdata(in: bodyRange) : Data()

        return IPCServerRequest(
            method: method,
            path: path,
            headers: headers,
            body: body
        )
    }

    private static func statusMessage(_ statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Response"
        }
    }
}
