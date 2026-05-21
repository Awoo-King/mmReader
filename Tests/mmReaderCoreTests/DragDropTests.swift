import AppKit
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func handleDroppedFileLoadsSupportedTextFile() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("drop.md")
    try "hello\nworld".write(to: file, atomically: true, encoding: .utf8)

    let wc = ReaderWindowController(configStore: ConfigStore(baseURL: tempRoot))
    let handled = wc.handleDroppedFile(file)

    #expect(handled == true)
    #expect(wc.currentDocumentPathForTesting == file.path)
}

@MainActor
@Test func handleDroppedFileRejectsUnsupportedFile() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("drop.pdf")
    try "fake".write(to: file, atomically: true, encoding: .utf8)

    let wc = ReaderWindowController(configStore: ConfigStore(baseURL: tempRoot))
    let handled = wc.handleDroppedFile(file)

    #expect(handled == false)
}
