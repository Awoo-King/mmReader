import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func synchronizerBuildsSnapshotFromSessionAndStore() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.windowWidth = 999
    store.save(cfg)

    let file = tempRoot.appendingPathComponent("sync.txt")
    try "hello\nworld".write(to: file, atomically: true, encoding: .utf8)

    var session = ReaderDocumentSession(configStore: store)
    let handled = session.handleDroppedFile(file)
    #expect(handled == true)

    let snapshot = ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: store)

    #expect(snapshot.documentPath == file.path)
    #expect(snapshot.anchor == 0)
    #expect(snapshot.config.windowWidth == 999)
}
