import AppKit
import Foundation
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func toolbarOpenPathReplacesDisplayedText() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("first.txt")
    let second = root.appendingPathComponent("second.txt")
    try "FIRST FILE".write(to: first, atomically: true, encoding: .utf8)
    try "SECOND FILE".write(to: second, atomically: true, encoding: .utf8)

    let wc = ReaderWindowController(configStore: ConfigStore(baseURL: root))
    _ = wc.handleDroppedFile(first)
    #expect(wc.displayedTextForTesting.contains("FIRST FILE"))

    wc.debugOpenDocumentFileForTesting(second)

    #expect(wc.displayedTextForTesting.contains("SECOND FILE"))
    #expect(wc.displayedTextForTesting.contains("FIRST FILE") == false)
}

@MainActor
@Test func applyingTextColorPersistsToConfig() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.debugSetTextColorHexForTesting("#33AAFF")
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.textColorHex == "#33AAFF")
}

@MainActor
@Test func windowIsBorderless() {
    let wc = ReaderWindowController()
    _ = wc.window
    #expect(wc.window?.styleMask.contains(.titled) == true)
    #expect(wc.window?.styleMask.contains(.resizable) == true)
}

@MainActor
@Test func commandBTogglesToolbarVisibility() {
    let wc = ReaderWindowController()
    let initial = wc.isToolbarVisible
    wc.toggleToolbar()
    #expect(wc.isToolbarVisible != initial)
}

@MainActor
@Test func openShortcutAdvertisedInHintText() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    #expect(wc.displayedTextForTesting.contains("⌘O"))
}

@MainActor
@Test func toolbarShortcutAdvertisedInHintText() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    #expect(wc.displayedTextForTesting.contains("⌘B"))
}

@MainActor
@Test func persistingWindowFrameUpdatesStoredGeometry() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.debugPersistWindowFrameForTesting(NSRect(x: 333, y: 444, width: 900, height: 901))

    let loaded = store.load()
    #expect(loaded.windowX == 333)
    #expect(loaded.windowY == 444)
    #expect(loaded.windowWidth == 900)
    #expect(loaded.windowHeight == 901)
}

@MainActor
@Test func toggleToolbarPersistsVisibilityState() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.toggleToolbar()
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.isToolbarVisible == false)
}

@MainActor
@Test func applyingLinesPerPageToConfigUpdatesPageLength() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let file = root.appendingPathComponent("paging.txt")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let text = (0..<30).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    var cfg = ReaderConfig.default
    cfg.linesPerPage = 5
    let store = ConfigStore(baseURL: root)
    store.save(cfg)
    let wc = ReaderWindowController(configStore: store)
    _ = wc.handleDroppedFile(file)

    #expect(wc.displayedTextForTesting.split(separator: "\n").count == 5)
}

@MainActor
@Test func applyingShellModeAndCloseBehaviorUpdatesConfig() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.debugApplyShellModeForTesting(.statusItemOnly)
    wc.debugApplyCloseBehaviorForTesting(.quitApp)
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.shellMode == .statusItemOnly)
    #expect(loaded.closeBehavior == .quitApp)
}

@MainActor
@Test func applyingShortcutChangeUpdatesConfig() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.debugApplyShortcutForTesting(action: "下一页", key: "j", modifiers: ["command"])
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.shortcuts.nextPage == .init(key: "j", modifiers: ["command"]))
}

@MainActor
@Test func applyingExpandedShortcutChangeUpdatesConfig() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.debugApplyShortcutForTesting(action: "显隐主窗口", key: "m", modifiers: ["command", "shift"])
    wc.debugApplyShortcutForTesting(action: "显隐 Controls", key: ",", modifiers: ["command"])
    wc.debugApplyShortcutForTesting(action: "切换置顶", key: "p", modifiers: ["command", "option"])
    wc.debugApplyShortcutForTesting(action: "隐藏工具栏", key: "h", modifiers: ["command", "shift"])
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.shortcuts.toggleMainWindow == .init(key: "m", modifiers: ["command", "shift"]))
    #expect(loaded.shortcuts.toggleControls == .init(key: ",", modifiers: ["command"]))
    #expect(loaded.shortcuts.togglePin == .init(key: "p", modifiers: ["command", "option"]))
    #expect(loaded.shortcuts.hideToolbar == .init(key: "h", modifiers: ["command", "shift"]))
}

@MainActor
@Test func openingSecondFileReplacesDisplayedText() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("first.txt")
    let second = root.appendingPathComponent("second.txt")
    try "FIRST FILE".write(to: first, atomically: true, encoding: .utf8)
    try "SECOND FILE".write(to: second, atomically: true, encoding: .utf8)

    let wc = ReaderWindowController(configStore: ConfigStore(baseURL: root))
    _ = wc.handleDroppedFile(first)
    #expect(wc.displayedTextForTesting.contains("FIRST FILE"))

    _ = wc.handleDroppedFile(second)
    #expect(wc.displayedTextForTesting.contains("SECOND FILE"))
    #expect(wc.displayedTextForTesting.contains("FIRST FILE") == false)
}

@MainActor
@Test func closeRequestInDockOnlyHidesWindowInsteadOfQuitting() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    var cfg = ReaderConfig.default
    cfg.shellMode = .dockOnly
    cfg.closeBehavior = .quitApp
    store.save(cfg)

    let wc = ReaderWindowController(configStore: store)
    _ = wc.window
    let shouldQuit = wc.debugHandleCloseRequestForTesting()

    #expect(shouldQuit == false)
    #expect(wc.window?.isVisible == false)
}

@MainActor
@Test func controlsPopoverUsesDedicatedViewController() {
    let wc = ReaderWindowController(configStore: ConfigStore())

    #expect(wc.debugControlsPopoverHasContentViewControllerForTesting == true)
    #expect(wc.debugControlsPopoverUsesDetachedControlsViewForTesting == true)
}

@MainActor
@Test func configuredCloseActionRequestsQuitWhenBehaviorIsQuitApp() {
    let wc = ReaderWindowController(configStore: ConfigStore())
    var didQuit = false
    wc.onQuitRequestedForApp = { didQuit = true }

    wc.debugApplyCloseBehaviorForTesting(.quitApp)
    wc.debugPerformConfiguredCloseActionForTesting()

    #expect(didQuit == true)
}

@MainActor
@Test func configuredCloseActionHidesWhenBehaviorIsHideWindow() {
    let wc = ReaderWindowController(configStore: ConfigStore())
    _ = wc.window

    wc.debugApplyCloseBehaviorForTesting(.hideWindow)
    wc.debugPerformConfiguredCloseActionForTesting()

    #expect(wc.window?.isVisible == false)
}

@MainActor
@Test func shellModeChangeNotifiesObserver() {
    let wc = ReaderWindowController(configStore: ConfigStore())
    var received: ReaderShellMode?
    wc.onShellModeChangedForApp = { received = $0 }

    wc.debugApplyShellModeForTesting(.statusItemOnly)

    #expect(received == .statusItemOnly)
}

@MainActor
@Test func shortcutChangeNotifiesObserver() {
    let wc = ReaderWindowController(configStore: ConfigStore())
    var received: ReaderShortcutBindings?
    wc.onShortcutsChangedForApp = { received = $0 }

    wc.debugApplyShortcutForTesting(action: "显隐主窗口", key: "m", modifiers: ["command"])

    #expect(received?.toggleMainWindow == .init(key: "m", modifiers: ["command"]))
}
