import AppKit
import Testing
import UniformTypeIdentifiers
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func appDelegateOpenDocumentReplacesDisplayedText() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let first = root.appendingPathComponent("first.txt")
    let second = root.appendingPathComponent("second.txt")
    try "FIRST FILE".write(to: first, atomically: true, encoding: .utf8)
    try "SECOND FILE".write(to: second, atomically: true, encoding: .utf8)

    let delegate = AppDelegate()
    let wc = ReaderWindowController(configStore: ConfigStore(baseURL: root))
    _ = wc.handleDroppedFile(first)
    delegate.windowController = wc

    delegate.debugOpenDocumentFile(second)

    #expect(wc.displayedTextForTesting.contains("SECOND FILE"))
    #expect(wc.displayedTextForTesting.contains("FIRST FILE") == false)
}

@MainActor
@Test func appDelegateOpenDocumentReplacesDisplayedTextForRealHarryPotterFixtures() throws {
    let root = URL(fileURLWithPath: "/Users/awoo/Downloads/小说/哈利波特/哈利波特（中文）", isDirectory: true)
    let first = root.appendingPathComponent("1哈利波特与魔法石.txt")
    let second = root.appendingPathComponent("2哈利波特与密室.txt")
    guard FileManager.default.fileExists(atPath: first.path), FileManager.default.fileExists(atPath: second.path) else {
        return
    }

    let delegate = AppDelegate()
    let wc = ReaderWindowController(configStore: ConfigStore())
    _ = wc.handleDroppedFile(first)
    delegate.windowController = wc

    let before = wc.displayedTextForTesting
    delegate.debugOpenDocumentFile(second)
    let after = wc.displayedTextForTesting

    #expect(before != after)
    #expect(after.contains("哈利·波特与密室") || after.contains("哈利波特与密室"))
}

@MainActor
@Test func statusItemControllerMenuItemsBindRealActions() {
    let controller = StatusItemController()
    let items = controller.debugMenuForTesting().items.filter { !$0.isSeparatorItem }

    #expect(items.allSatisfy { $0.action != nil })
    #expect(items.allSatisfy { ($0.target as AnyObject?) === controller })
}

@MainActor
@Test func statusItemControllerRemovesAndRestoresBackingStatusItem() {
    let controller = StatusItemController()

    #expect(controller.debugHasStatusItemForTesting == true)
    controller.setVisible(false)
    #expect(controller.debugHasStatusItemForTesting == false)
    controller.setVisible(true)
    #expect(controller.debugHasStatusItemForTesting == true)
}

@MainActor
@Test func appDelegateBuildsExpandedRuntimeMenuItems() {
    let delegate = AppDelegate()
    var cfg = ReaderConfig.default
    cfg.shortcuts.toggleMainWindow = .init(key: "m", modifiers: ["command"])
    cfg.shortcuts.toggleControls = .init(key: ",", modifiers: ["command"])
    cfg.shortcuts.togglePin = .init(key: "p", modifiers: ["command"])
    cfg.shortcuts.hideToolbar = .init(key: "h", modifiers: ["command", "shift"])
    cfg.shortcuts.closeWindow = .init(key: "w", modifiers: ["command"])

    let menu = delegate.debugBuildMainMenu(config: cfg)
    let navigateMenu = menu.items[2].submenu

    let toggleWindowItem = navigateMenu?.items.first(where: { $0.title == "Toggle Window" })
    let controlsItem = navigateMenu?.items.first(where: { $0.title == "Toggle Controls" })
    let pinItem = navigateMenu?.items.first(where: { $0.title == "Toggle Pin" })
    let hideItem = navigateMenu?.items.first(where: { $0.title == "Hide Toolbar" })
    let closeItem = navigateMenu?.items.first(where: { $0.title == "Close Window" })

    #expect(toggleWindowItem?.keyEquivalent == "m")
    #expect(controlsItem?.keyEquivalent == ",")
    #expect(pinItem?.keyEquivalent == "p")
    #expect(hideItem?.keyEquivalent == "h")
    #expect(closeItem?.keyEquivalent == "w")
}

@MainActor
@Test func statusItemControllerPresentsMenuWithoutUsingAttachedMenu() {
    let controller = StatusItemController()

    controller.debugShowMenuForTesting()

    #expect(controller.debugHasAttachedMenuForTesting == false)
}

@MainActor
@Test func appDelegateReopensHiddenWindowFromDock() {
    let delegate = AppDelegate()
    let wc = ReaderWindowController(configStore: ConfigStore())
    _ = wc.window
    wc.hideWindowForTesting()
    delegate.windowController = wc

    let handled = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)

    #expect(handled == true)
    #expect(wc.window?.isVisible == true)
}

@MainActor
@Test func appDelegateBuildsLeftAndRightArrowShortcutsFromConfig() {
    let delegate = AppDelegate()
    var cfg = ReaderConfig.default
    cfg.shortcuts.previousPage = .init(key: "leftArrow")
    cfg.shortcuts.nextPage = .init(key: "rightArrow")

    let menu = delegate.debugBuildMainMenu(config: cfg)
    let navMenu = menu.items[2].submenu
    let nextItem = navMenu?.items.first(where: { $0.title == "Next Page" })
    let prevItem = navMenu?.items.first(where: { $0.title == "Previous Page" })

    #expect(nextItem?.keyEquivalent == String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)))
    #expect(prevItem?.keyEquivalent == String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)))
}

@MainActor
@Test func appDelegateBuildsMenuFromConfiguredShortcuts() {
    let delegate = AppDelegate()
    var cfg = ReaderConfig.default
    cfg.shortcuts.openFile = .init(key: "f", modifiers: ["command", "shift"])
    cfg.shortcuts.toggleToolbar = .init(key: "t", modifiers: ["command"])

    let menu = delegate.debugBuildMainMenu(config: cfg)
    let fileMenu = menu.items[1].submenu
    let navigateMenu = menu.items[2].submenu

    let openItem = fileMenu?.items.first(where: { $0.title == "Open…" })
    let toggleItem = navigateMenu?.items.first(where: { $0.title == "Toggle Toolbar" })

    #expect(openItem?.keyEquivalent == "f")
    #expect(openItem?.keyEquivalentModifierMask == NSEvent.ModifierFlags([.command, .shift]))
    #expect(toggleItem?.keyEquivalent == "t")
    #expect(toggleItem?.keyEquivalentModifierMask == NSEvent.ModifierFlags([.command]))
}

@MainActor
@Test func appDelegateRebuildsMainMenuAfterShortcutChange() {
    let delegate = AppDelegate()
    var cfg = ReaderConfig.default
    cfg.shortcuts.toggleToolbar = .init(key: "t", modifiers: ["command"])

    let menu = delegate.debugBuildMainMenu(config: cfg)
    let navMenu = menu.items[2].submenu
    let toggleItem = navMenu?.items.first(where: { $0.title == "Toggle Toolbar" })

    #expect(toggleItem?.keyEquivalent == "t")
}

@MainActor
@Test func appDelegateBuildsToolbarShortcutMenuItem() {
    let delegate = AppDelegate()
    let menu = delegate.debugBuildMainMenu()
    let navigateMenu = menu.items[2].submenu
    let toggleItem = navigateMenu?.items.first(where: { $0.keyEquivalent == "b" })

    #expect(toggleItem?.keyEquivalentModifierMask == NSEvent.ModifierFlags.command)
}

@MainActor
@Test func appDelegateBuildsArrowPagingShortcuts() {
    let delegate = AppDelegate()
    let menu = delegate.debugBuildMainMenu()
    let navMenu = menu.items[2].submenu

    let nextItem = navMenu?.items.first(where: { $0.title == "Next Page" })
    let prevItem = navMenu?.items.first(where: { $0.title == "Previous Page" })

    #expect(nextItem?.keyEquivalent == String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)))
    #expect(prevItem?.keyEquivalent == String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)))
}

@MainActor
@Test func appDelegateOpenPanelContentTypesAllowPlainTextAndMarkdown() {
    let contentTypes = AppDelegate.openDocumentContentTypes

    #expect(contentTypes.contains(UTType.plainText))
    #expect(contentTypes.contains(where: { $0.identifier == "net.daringfireball.markdown" }))
}

@MainActor
@Test func statusItemControllerBuildsRequiredMenuItems() {
    let controller = StatusItemController()
    let titles = controller.debugMenuForTesting().items.map(\.title)

    #expect(titles.contains("显示窗口"))
    #expect(titles.contains("隐藏窗口"))
    #expect(titles.contains("置顶"))
    #expect(titles.contains("打开文件"))
    #expect(titles.contains("退出"))
}

@MainActor
@Test func statusItemPrimaryClickTriggersToggleWindow() {
    let controller = StatusItemController()
    var toggleCount = 0
    controller.onToggleWindow = { toggleCount += 1 }

    controller.debugPerformPrimaryClickForTesting()

    #expect(toggleCount == 1)
}

@MainActor
@Test func statusItemControllerTriggersActions() {
    let controller = StatusItemController()
    var toggleCount = 0
    var showCount = 0
    var hideCount = 0
    var pinCount = 0
    var openCount = 0
    var quitCount = 0

    controller.onToggleWindow = { toggleCount += 1 }
    controller.onShowWindow = { showCount += 1 }
    controller.onHideWindow = { hideCount += 1 }
    controller.onTogglePin = { pinCount += 1 }
    controller.onOpenFile = { openCount += 1 }
    controller.onQuit = { quitCount += 1 }

    controller.debugTriggerToggleWindowForTesting()
    controller.debugTriggerShowWindowForTesting()
    controller.debugTriggerHideWindowForTesting()
    controller.debugTriggerTogglePinForTesting()
    controller.debugTriggerOpenFileForTesting()
    controller.debugTriggerQuitForTesting()

    #expect(toggleCount == 1)
    #expect(showCount == 1)
    #expect(hideCount == 1)
    #expect(pinCount == 1)
    #expect(openCount == 1)
    #expect(quitCount == 1)
}

@MainActor
@Test func dockOnlyRemovesStatusItemEvenAfterItWasVisible() {
    let controller = StatusItemController()

    controller.setVisible(true)
    #expect(controller.debugHasStatusItemForTesting == true)

    controller.setVisible(false)
    #expect(controller.debugHasStatusItemForTesting == false)
}

@MainActor
@Test func statusItemVisibilityFollowsShellMode() {
    let delegate = AppDelegate()

    delegate.debugApplyShellMode(.dockOnly)
    #expect(delegate.debugStatusItemVisibleForTesting == false)
    #expect(delegate.debugStatusItemInstalledForTesting == false)

    delegate.debugApplyShellMode(.statusItemOnly)
    #expect(delegate.debugStatusItemVisibleForTesting == true)
    #expect(delegate.debugStatusItemInstalledForTesting == true)

    delegate.debugApplyShellMode(.dockAndStatusItem)
    #expect(delegate.debugStatusItemVisibleForTesting == true)
    #expect(delegate.debugStatusItemInstalledForTesting == true)
}

@MainActor
@Test func appDelegateAppliesShellModePresentationPolicy() {
    let delegate = AppDelegate()

    #expect(delegate.debugActivationPolicy(for: .dockOnly) == .regular)
    #expect(delegate.debugActivationPolicy(for: .statusItemOnly) == .accessory)
    #expect(delegate.debugActivationPolicy(for: .dockAndStatusItem) == .regular)
}

@MainActor
@Test func closeBehaviorCanResolveToHideOrQuit() {
    let delegate = AppDelegate()

    #expect(delegate.debugShouldQuitOnClose(.hideWindow) == false)
    #expect(delegate.debugShouldQuitOnClose(.quitApp) == true)
}

@MainActor
@Test func statusItemControllerAppliesVisibleStateToStatusItem() {
    let controller = StatusItemController()

    controller.setVisible(false)
    #expect(controller.debugIsVisibleForTesting == false)

    controller.setVisible(true)
    #expect(controller.debugIsVisibleForTesting == true)
}
