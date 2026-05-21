import Foundation
import Testing
@testable import mmReaderCore

@Test func openFileAtomicallyFailureKeepsCurrentDocumentAndPage() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let goodFile = tempRoot.appendingPathComponent("good.txt")
    let badFile = tempRoot.appendingPathComponent("bad.pdf")

    try (0..<120).map { "line \($0)" }.joined(separator: "\n").write(to: goodFile, atomically: true, encoding: .utf8)
    try "fake pdf".write(to: badFile, atomically: true, encoding: .utf8)

    var engine = ReaderEngine(linesPerPage: 10)
    try engine.load(url: goodFile)
    engine.goToPage(4)

    let beforePage = engine.currentPageIndex
    let beforeAnchor = engine.currentAnchor
    let beforePages = engine.pages

    do {
        try engine.openFileAtomically(badFile)
        Issue.record("Expected unsupported format error")
    } catch ReaderEngineError.unsupportedFormat {
    } catch {
        Issue.record("Expected unsupported format, got \(error)")
    }

    #expect(engine.currentPageIndex == beforePage)
    #expect(engine.currentAnchor == beforeAnchor)
    #expect(engine.pages == beforePages)
}
