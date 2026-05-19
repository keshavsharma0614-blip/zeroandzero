import Foundation
import Testing
@testable import TradingKit

@Test("AgentControlRuntimeInfoStore save writes 0600")
func ipcRuntimeStoreSaveWritesExpectedPermissions() throws {
    let root = makeTempDirectory(name: "ipc-runtime-save")
    let fileURL = root.appendingPathComponent("ipc.json", isDirectory: false)
    let store = AgentControlRuntimeInfoStore(fileURL: fileURL)

    try store.save(AgentControlRuntimeInfo(host: "127.0.0.1", port: 8765, token: "token-a"))

    #expect(FileManager.default.fileExists(atPath: fileURL.path))
    let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
    #expect(mode & 0o777 == 0o600)
}

@Test("AgentControlRuntimeInfoStore clear removes file")
func ipcRuntimeStoreClearRemovesFile() throws {
    let root = makeTempDirectory(name: "ipc-runtime-clear")
    let fileURL = root.appendingPathComponent("ipc.json", isDirectory: false)
    let store = AgentControlRuntimeInfoStore(fileURL: fileURL)

    try store.save(AgentControlRuntimeInfo(host: "127.0.0.1", port: 8765, token: "token-a"))
    #expect(FileManager.default.fileExists(atPath: fileURL.path))

    try store.clear()
    #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
}

@Test("AgentControlRuntimeInfoStore save overwrites and updates mtime")
func ipcRuntimeStoreSaveOverwritesAndUpdatesMTime() throws {
    let root = makeTempDirectory(name: "ipc-runtime-overwrite")
    let fileURL = root.appendingPathComponent("ipc.json", isDirectory: false)
    let store = AgentControlRuntimeInfoStore(fileURL: fileURL)

    try store.save(AgentControlRuntimeInfo(host: "127.0.0.1", port: 8765, token: "token-a"))

    let oldMTime = Date(timeIntervalSince1970: 1_000)
    try FileManager.default.setAttributes([.modificationDate: oldMTime], ofItemAtPath: fileURL.path)

    try store.save(AgentControlRuntimeInfo(host: "127.0.0.1", port: 8766, token: "token-b"))

    let loaded = try store.load()
    #expect(loaded.port == 8766)
    #expect(loaded.token == "token-b")

    let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let updatedMTime = (attrs[.modificationDate] as? Date) ?? .distantPast
    #expect(updatedMTime > oldMTime)
}

private func makeTempDirectory(name: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TradingKitTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
