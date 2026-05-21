import AppKit
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func startupRestoresLastFileAndAnchor() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("restore.txt")
    let text = (0..<180).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.lastFilePath = file.path
    cfg.lastAnchor = 320
    store.save(cfg)

    let wc = ReaderWindowController(configStore: store)

    #expect(wc.currentDocumentPathForTesting == file.path)
    #expect(wc.currentAnchorForTesting == 320)
}
