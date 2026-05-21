import AppKit
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@MainActor
@Test func controllerMaintainBehaviorsAfterCleanup() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("restore.txt")
    try (0..<120).map { "line \($0)" }.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.lastFilePath = file.path
    cfg.lastAnchor = 123
    store.save(cfg)

    let wc = ReaderWindowController(configStore: store)
    #expect(wc.currentDocumentPathForTesting == file.path)
    #expect(wc.currentAnchorForTesting == 123)

    let before = wc.isToolbarVisible
    wc.toggleToolbar()
    #expect(wc.isToolbarVisible != before)
}
