import Foundation
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@Test func documentSessionRestoresLastFileAndAnchor() throws {
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

    var session = ReaderDocumentSession(configStore: store)
    session.restoreFromConfig()

    #expect(session.currentDocumentPath == file.path)
    #expect(session.currentAnchor == 320)
}

@Test func documentSessionDropRejectsUnsupportedFile() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("drop.pdf")
    try "fake".write(to: file, atomically: true, encoding: .utf8)

    var session = ReaderDocumentSession(configStore: ConfigStore(baseURL: tempRoot))
    let handled = session.handleDroppedFile(file)

    #expect(handled == false)
    #expect(session.currentDocumentPath == nil)
}
