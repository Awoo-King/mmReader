import Foundation
import Testing
@testable import mmReaderCore

@Test func decodeInvalidConfigFallsBackToDefaults() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    try "{ invalid json".write(to: store.configURL, atomically: true, encoding: .utf8)

    let cfg = store.load()

    #expect(cfg.fontSize == ReaderConfig.default.fontSize)
    #expect(cfg.linesPerPage == ReaderConfig.default.linesPerPage)
    #expect(cfg.lastPageIndex == 0)
    #expect(cfg.lastFilePath == nil)
}

@Test func roundTripPersistsLastAnchor() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.lastAnchor = 1200

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.lastAnchor == 1200)
}

@Test func saveThenLoadPreservesWindowGeometryAndFlags() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.windowX = 420
    cfg.windowY = 360
    cfg.windowWidth = 900
    cfg.windowHeight = 1200
    cfg.isPinned = true
    cfg.isFullscreen = true
    cfg.lastFilePath = "/tmp/demo.txt"
    cfg.lastPageIndex = 8
    cfg.lastAnchor = 2400

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.windowX == 420)
    #expect(loaded.windowY == 360)
    #expect(loaded.windowWidth == 900)
    #expect(loaded.windowHeight == 1200)
    #expect(loaded.isPinned == true)
    #expect(loaded.isFullscreen == true)
    #expect(loaded.lastFilePath == "/tmp/demo.txt")
    #expect(loaded.lastPageIndex == 8)
    #expect(loaded.lastAnchor == 2400)
}

@Test func saveThenLoadPreservesShellModeCloseBehaviorAndShortcuts() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.shellMode = .statusItemOnly
    cfg.closeBehavior = .quitApp
    cfg.shortcuts.nextPage = .init(key: "downArrow")
    cfg.shortcuts.previousPage = .init(key: "upArrow")
    cfg.shortcuts.closeWindow = .init(key: "w", modifiers: ["command"])

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.shellMode == .statusItemOnly)
    #expect(loaded.closeBehavior == .quitApp)
    #expect(loaded.shortcuts.nextPage == .init(key: "downArrow"))
    #expect(loaded.shortcuts.previousPage == .init(key: "upArrow"))
    #expect(loaded.shortcuts.closeWindow == .init(key: "w", modifiers: ["command"]))
}

@Test func saveThenLoadPreservesExpandedShortcutBindings() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.shortcuts.toggleMainWindow = .init(key: "m", modifiers: ["command", "shift"])
    cfg.shortcuts.toggleControls = .init(key: ",", modifiers: ["command"])
    cfg.shortcuts.togglePin = .init(key: "p", modifiers: ["command", "option"])
    cfg.shortcuts.hideToolbar = .init(key: "h", modifiers: ["command", "shift"])

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.shortcuts.toggleMainWindow == .init(key: "m", modifiers: ["command", "shift"]))
    #expect(loaded.shortcuts.toggleControls == .init(key: ",", modifiers: ["command"]))
    #expect(loaded.shortcuts.togglePin == .init(key: "p", modifiers: ["command", "option"]))
    #expect(loaded.shortcuts.hideToolbar == .init(key: "h", modifiers: ["command", "shift"]))
}

@Test func saveThenLoadPreservesTextColor() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.textColorHex = "#33AAFF"

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.textColorHex == "#33AAFF")
}
