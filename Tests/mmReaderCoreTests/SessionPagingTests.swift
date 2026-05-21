import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func interactorPagingMovesForwardThenBackward() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    var cfg = ReaderConfig.default
    cfg.linesPerPage = 5
    let store = ConfigStore(baseURL: tempRoot)
    store.save(cfg)

    let file = tempRoot.appendingPathComponent("book.txt")
    let text = (0..<120).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    var interactor = ReaderSessionInteractor(configStore: store)

    let (handled, initial) = interactor.handleDroppedFile(file)
    #expect(handled == true)
    #expect(initial.pageText.split(separator: "\n").count == 5)

    let (movedNext, snapshotNext) = interactor.moveToNextPage()
    #expect(movedNext == true)
    #expect(snapshotNext.pageIndex > 0)

    let (movedPrev, snapshotPrev) = interactor.moveToPreviousPage()
    #expect(movedPrev == true)
    #expect(snapshotPrev.pageIndex == 0)
}
