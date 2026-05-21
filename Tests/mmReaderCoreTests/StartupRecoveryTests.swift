import AppKit
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func windowRestoresGeometryFromStoredConfig() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.windowX = 251
    cfg.windowY = 361
    cfg.windowWidth = 912
    cfg.windowHeight = 1004
    cfg.isPinned = true
    store.save(cfg)

    let wc = ReaderWindowController(configStore: store)
    let frame = wc.window?.frame

    #expect(frame?.origin.x == 251)
    #expect(frame?.origin.y == 361)
    #expect(frame?.size.width == 912)
    #expect(frame?.size.height == 1004)
    #expect(wc.window?.level == .floating)
}
