import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func interactorRestoreReturnsSnapshotWithRestoredPath() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("restore.txt")
    let text = (0..<120).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.lastFilePath = file.path
    cfg.lastAnchor = 180
    store.save(cfg)

    var interactor = ReaderSessionInteractor(configStore: store)
    let snapshot = interactor.restore()

    #expect(snapshot.documentPath == file.path)
    #expect(snapshot.anchor == 180)
}

@Test func openingSecondFileReplacesSnapshotContent() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let first = tempRoot.appendingPathComponent("first.txt")
    let second = tempRoot.appendingPathComponent("second.txt")
    try "FIRST FILE".write(to: first, atomically: true, encoding: .utf8)
    try "SECOND FILE".write(to: second, atomically: true, encoding: .utf8)

    var interactor = ReaderSessionInteractor(configStore: ConfigStore(baseURL: tempRoot))

    let (_, firstSnapshot) = interactor.handleDroppedFile(first)
    let (_, secondSnapshot) = interactor.handleDroppedFile(second)

    #expect(firstSnapshot.documentPath == first.path)
    #expect(secondSnapshot.documentPath == second.path)
    #expect(firstSnapshot.pageText.contains("FIRST FILE"))
    #expect(secondSnapshot.pageText.contains("SECOND FILE"))
    #expect(secondSnapshot.pageText.contains("FIRST FILE") == false)
}
