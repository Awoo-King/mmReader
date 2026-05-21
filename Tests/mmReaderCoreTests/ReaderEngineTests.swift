import Foundation
import Testing
@testable import mmReaderCore

@Test func supportsTxtAndMdOnly() {
    #expect(ReaderEngine.supports(url: URL(fileURLWithPath: "/tmp/a.txt")))
    #expect(ReaderEngine.supports(url: URL(fileURLWithPath: "/tmp/a.md")))
    #expect(!ReaderEngine.supports(url: URL(fileURLWithPath: "/tmp/a.pdf")))
}

@Test func repaginateKeepsSemanticPositionByAnchor() throws {
    var engine = ReaderEngine(linesPerPage: 10)
    let longText = (0..<200).map { "line \($0)" }.joined(separator: "\n")

    try engine.load(text: longText)
    engine.goToPage(5)
    let beforeAnchor = engine.currentAnchor

    engine.repaginate(linesPerPage: 20)

    #expect(abs(engine.currentAnchor - beforeAnchor) <= 120)
}

@Test func engineOpensUtf8File() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    let file = tempRoot.appendingPathComponent("utf8.txt")
    try "hello utf8".write(to: file, atomically: true, encoding: .utf8)

    var engine = ReaderEngine()
    try engine.openFileAtomically(file)

    #expect(engine.pages.joined().contains("hello utf8"))
}

@Test func engineOpensGb18030File() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    let file = tempRoot.appendingPathComponent("gb18030.txt")
    let text = "中文内容"
    let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    guard let data = text.data(using: encoding) else {
        Issue.record("failed to encode test fixture as GB18030")
        return
    }
    try data.write(to: file)

    var engine = ReaderEngine()
    try engine.openFileAtomically(file)

    #expect(engine.pages.joined().contains("中文内容"))
}

@Test func loadHonorsConfiguredLinesPerPage() throws {
    var engine = ReaderEngine(linesPerPage: 5)
    let text = (0..<12).map { "line \($0)" }.joined(separator: "\n")

    try engine.load(text: text)

    #expect(engine.pages.count == 3)
    #expect(engine.pages[0].split(separator: "\n").count == 5)
}
