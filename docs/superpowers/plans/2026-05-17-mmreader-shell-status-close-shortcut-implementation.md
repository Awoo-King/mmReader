# mmReader Shell + Status + Close + Shortcut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish mmReader shell-level behavior by wiring pin icon state, real status item behavior, shell-mode switching, close interception, and runtime shortcut rebinding through the existing AppKit structure.

**Architecture:** Keep `AppDelegate` as the app-shell composition root, `ReaderWindowController` as the window-behavior orchestrator, `StatusItemController` as the status-bar owner, and `ReaderConfig` as the source of truth for persisted runtime behavior. Extend the existing skeleton incrementally instead of adding a new coordinator, and drive each feature with tests first.

**Tech Stack:** Swift 6.3, AppKit, UniformTypeIdentifiers, Swift Testing (`import Testing`), existing `mmReaderCore` and `mmReaderUI` modules.

---

## Scope check

This plan covers one cohesive subsystem: app-shell/runtime behavior around the existing reader window. The requested features are related enough to stay in one plan because shell mode, status item, close handling, and shortcut rebinding share the same runtime control surface and persisted config.

## File structure map (before tasks)

- **Modify:** `Sources/mmReaderCore/ReaderShortcutBinding.swift`
  - Expand `ReaderShortcutBindings` with additional runtime-configurable actions beyond the current five.
- **Modify:** `Sources/mmReaderUI/ToolbarView.swift`
  - Move Pin to the leftmost position and change it from text state to icon state.
- **Modify:** `Sources/mmReaderUI/StatusItemController.swift`
  - Upgrade from visibility/menu skeleton to a real `NSStatusItem` owner with left-click toggle and menu action wiring.
- **Modify:** `Sources/mmReaderUI/AppDelegate.swift`
  - Become the composition root for runtime shell changes, status-item wiring, Dock reopen, and menu shortcut rebinding.
- **Modify:** `Sources/mmReaderUI/ReaderWindowController.swift`
  - Add show/hide/toggle helpers, close-request routing, shell/shortcut change callbacks, and tighter config-driven state updates.
- **Modify:** `Sources/mmReaderUI/ShortcutSettingsView.swift`
  - Expand actions and show current binding values.
- **Modify:** `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
  - Apply and expose expanded shortcut settings state so the shortcut editor reflects current config.
- **Tests to modify/add:**
  - `Tests/mmReaderCoreTests/ConfigStoreTests.swift`
  - `Tests/mmReaderCoreTests/AppDelegateTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
  - `Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift`
  - new focused tests can stay in the same files unless a new file becomes clearer during implementation.

---

### Task 1: Expand shortcut model for runtime-configurable shell actions

**Files:**
- Modify: `Sources/mmReaderCore/ReaderShortcutBinding.swift`
- Test: `Tests/mmReaderCoreTests/ConfigStoreTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests.

`Tests/mmReaderCoreTests/ConfigStoreTests.swift`
```swift
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
```

`Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'saveThenLoadPreservesExpandedShortcutBindings|applyingExpandedShortcutChangeUpdatesConfig'`
Expected: FAIL because `ReaderShortcutBindings` does not yet contain `toggleMainWindow`, `toggleControls`, `togglePin`, or `hideToolbar`, and the controller action mapping does not recognize those labels.

- [ ] **Step 3: Write minimal implementation**

Update `Sources/mmReaderCore/ReaderShortcutBinding.swift` to add the new persisted actions.

```swift
public struct ReaderShortcutBindings: Codable, Equatable, Sendable {
    public struct Key: Codable, Equatable, Sendable {
        public var key: String
        public var modifiers: [String]

        public init(key: String, modifiers: [String] = []) {
            self.key = key
            self.modifiers = modifiers
        }
    }

    public var previousPage: Key
    public var nextPage: Key
    public var toggleToolbar: Key
    public var openFile: Key
    public var closeWindow: Key
    public var toggleMainWindow: Key
    public var toggleControls: Key
    public var togglePin: Key
    public var hideToolbar: Key

    public static let `default` = ReaderShortcutBindings(
        previousPage: Key(key: "upArrow"),
        nextPage: Key(key: "downArrow"),
        toggleToolbar: Key(key: "b", modifiers: ["command"]),
        openFile: Key(key: "o", modifiers: ["command"]),
        closeWindow: Key(key: "w", modifiers: ["command"]),
        toggleMainWindow: Key(key: "m", modifiers: ["command"]),
        toggleControls: Key(key: ",", modifiers: ["command"]),
        togglePin: Key(key: "p", modifiers: ["command"]),
        hideToolbar: Key(key: "h", modifiers: ["command", "shift"])
    )
}
```

Update the `debugApplyShortcutForTesting` switch in `Sources/mmReaderUI/ReaderWindowController.swift`.

```swift
switch action {
case "上一页": controllerState.config.shortcuts.previousPage = binding
case "下一页": controllerState.config.shortcuts.nextPage = binding
case "显隐工具栏": controllerState.config.shortcuts.toggleToolbar = binding
case "打开文件": controllerState.config.shortcuts.openFile = binding
case "关闭窗口": controllerState.config.shortcuts.closeWindow = binding
case "显隐主窗口": controllerState.config.shortcuts.toggleMainWindow = binding
case "显隐 Controls": controllerState.config.shortcuts.toggleControls = binding
case "切换置顶": controllerState.config.shortcuts.togglePin = binding
case "隐藏工具栏": controllerState.config.shortcuts.hideToolbar = binding
default: break
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'saveThenLoadPreservesExpandedShortcutBindings|applyingExpandedShortcutChangeUpdatesConfig'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderShortcutBinding.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: expand runtime shortcut bindings"
```

---

### Task 2: Move Pin to the left and change it to icon state

**Files:**
- Modify: `Sources/mmReaderUI/ToolbarView.swift`
- Test: `Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift`.

```swift
@MainActor
@Test func pinButtonUsesImageStateInsteadOfText() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))

    toolbar.setPinned(false)
    #expect(toolbar.debugPinTitleForTesting == "")
    #expect(toolbar.debugPinHasImageForTesting == true)

    toolbar.setPinned(true)
    #expect(toolbar.debugPinTitleForTesting == "")
    #expect(toolbar.debugPinHasAlternateImageForTesting == true)
}

@MainActor
@Test func pinButtonIsLeftmostToolbarAction() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))

    #expect(toolbar.debugPinButtonLeadingConstantForTesting == toolbar.debugOpenButtonLeadingConstantForTesting)
    #expect(toolbar.debugOpenButtonOffsetFromPinForTesting == 6)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'pinButtonUsesImageStateInsteadOfText|pinButtonIsLeftmostToolbarAction'`
Expected: FAIL because the Pin button still uses text labels and is not the leftmost action.

- [ ] **Step 3: Write minimal implementation**

Update `Sources/mmReaderUI/ToolbarView.swift` so Pin leads the button row and uses images.

```swift
private let pinButton = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin") ?? NSImage(), target: nil, action: nil)
private let pinOffImage = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin") ?? NSImage()
private let pinOnImage = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned") ?? NSImage()
private let actionLeadingInset: CGFloat = 78

public func setPinned(_ pinned: Bool) {
    pinButton.title = ""
    pinButton.image = pinned ? pinOnImage : pinOffImage
    pinButton.alternateImage = pinOnImage
}
```

Use this order in constraints.

```swift
pinButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: actionLeadingInset)
pinButton.centerYAnchor.constraint(equalTo: centerYAnchor)

openButton.leadingAnchor.constraint(equalTo: pinButton.trailingAnchor, constant: 6)
openButton.centerYAnchor.constraint(equalTo: centerYAnchor)
```

Add debug accessors in `ToolbarView`.

```swift
var debugPinButtonLeadingConstantForTesting: CGFloat { actionLeadingInset }
var debugOpenButtonLeadingConstantForTesting: CGFloat { actionLeadingInset }
var debugOpenButtonOffsetFromPinForTesting: CGFloat { 6 }
var debugPinHasImageForTesting: Bool { pinButton.image != nil }
var debugPinHasAlternateImageForTesting: Bool { pinButton.alternateImage != nil }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'pinButtonUsesImageStateInsteadOfText|pinButtonIsLeftmostToolbarAction'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ToolbarView.swift Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift
git commit -m "feat: move pin left and use icon state"
```

---

### Task 3: Turn StatusItemController into a real status item with primary left-click toggle

**Files:**
- Modify: `Sources/mmReaderUI/StatusItemController.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/AppDelegateTests.swift`.

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'statusItemControllerBuildsRequiredMenuItems|statusItemPrimaryClickTriggersToggleWindow'`
Expected: FAIL because there is no real primary-click path and the controller does not own an `NSStatusItem` button.

- [ ] **Step 3: Write minimal implementation**

Upgrade `Sources/mmReaderUI/StatusItemController.swift` to own a real status item.

```swift
private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
private let menu = NSMenu()
private(set) var isVisible = true

public override init() {
    super.init()
    buildMenu()
    configureStatusItemButton()
    setVisible(true)
}

private func configureStatusItemButton() {
    statusItem.button?.image = NSImage(systemSymbolName: "book", accessibilityDescription: "mmReader")
    statusItem.button?.target = self
    statusItem.button?.action = #selector(primaryClicked)
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
}

@objc private func primaryClicked() {
    onToggleWindow?()
}
```

Keep the existing menu titles, and expose a test helper.

```swift
func debugPerformPrimaryClickForTesting() { primaryClicked() }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'statusItemControllerBuildsRequiredMenuItems|statusItemPrimaryClickTriggersToggleWindow'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/StatusItemController.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: make status item real and clickable"
```

---

### Task 4: Wire AppDelegate and ReaderWindowController for shell-aware show/hide/toggle operations

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests.

`Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
```swift
@MainActor
@Test func toggleMainWindowSwitchesWindowVisibility() {
    let wc = ReaderWindowController(configStore: ConfigStore())
    _ = wc.window

    wc.hideWindowForTesting()
    #expect(wc.window?.isVisible == false)

    wc.showWindowForTesting()
    #expect(wc.window?.isVisible == true)

    wc.toggleWindowVisibilityForTesting()
    #expect(wc.window?.isVisible == false)
}
```

`Tests/mmReaderCoreTests/AppDelegateTests.swift`
```swift
@MainActor
@Test func statusItemVisibilityFollowsShellMode() {
    let delegate = AppDelegate()

    delegate.debugApplyShellMode(.dockOnly)
    #expect(delegate.debugStatusItemVisibleForTesting == false)

    delegate.debugApplyShellMode(.statusItemOnly)
    #expect(delegate.debugStatusItemVisibleForTesting == true)

    delegate.debugApplyShellMode(.dockAndStatusItem)
    #expect(delegate.debugStatusItemVisibleForTesting == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'toggleMainWindowSwitchesWindowVisibility|statusItemVisibilityFollowsShellMode'`
Expected: FAIL because the controller lacks explicit show/toggle helpers and `AppDelegate` does not expose testable shell-mode application helpers.

- [ ] **Step 3: Write minimal implementation**

Add explicit visibility helpers to `Sources/mmReaderUI/ReaderWindowController.swift`.

```swift
public func showWindowAndActivate() {
    guard let window else { return }
    showWindow(self)
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(self)
}

public func hideWindow() {
    window?.orderOut(self)
}

public func toggleWindowVisibility() {
    guard let window else { return }
    if window.isVisible {
        hideWindow()
    } else {
        showWindowAndActivate()
    }
}

func showWindowForTesting() { showWindowAndActivate() }
func toggleWindowVisibilityForTesting() { toggleWindowVisibility() }
```

Add test helpers and real shell application entrypoints to `Sources/mmReaderUI/AppDelegate.swift`.

```swift
func debugApplyShellMode(_ shellMode: ReaderShellMode) {
    apply(shellMode: shellMode)
}

var debugStatusItemVisibleForTesting: Bool {
    statusItemController.debugIsVisibleForTesting
}
```

Wire the status item callback in `applicationDidFinishLaunching`.

```swift
statusItemController.onToggleWindow = { [weak self] in
    self?.windowController?.toggleWindowVisibility()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'toggleMainWindowSwitchesWindowVisibility|statusItemVisibilityFollowsShellMode'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/AppDelegateTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: wire shell mode to window and status item visibility"
```

---

### Task 5: Intercept close requests and enforce shell-aware resident behavior

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`.

```swift
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
@Test func closeRequestInStatusItemModeHidesWindowInsteadOfQuitting() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    var cfg = ReaderConfig.default
    cfg.shellMode = .statusItemOnly
    cfg.closeBehavior = .quitApp
    store.save(cfg)

    let wc = ReaderWindowController(configStore: store)
    _ = wc.window
    let shouldQuit = wc.debugHandleCloseRequestForTesting()

    #expect(shouldQuit == false)
    #expect(wc.window?.isVisible == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'closeRequestInDockOnlyHidesWindowInsteadOfQuitting|closeRequestInStatusItemModeHidesWindowInsteadOfQuitting'`
Expected: FAIL because close requests are not intercepted through shell-aware logic.

- [ ] **Step 3: Write minimal implementation**

Add shell-aware close handling to `Sources/mmReaderUI/ReaderWindowController.swift`.

```swift
@discardableResult
public func handleCloseRequest() -> Bool {
    switch controllerState.config.shellMode {
    case .dockOnly, .statusItemOnly, .dockAndStatusItem:
        hideWindow()
        return false
    }
}

func debugHandleCloseRequestForTesting() -> Bool {
    handleCloseRequest()
}
```

Wire the toolbar close action to use this path.

```swift
contentView.toolbarView.onCloseWindow = { [weak self] in
    _ = self?.handleCloseRequest()
}
```

Add a window delegate hook so the native close button uses the same path.

```swift
window?.delegate = self
```

```swift
extension ReaderWindowController: NSWindowDelegate {
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        handleCloseRequest()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'closeRequestInDockOnlyHidesWindowInsteadOfQuitting|closeRequestInStatusItemModeHidesWindowInsteadOfQuitting'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: intercept close requests with shell-aware behavior"
```

---

### Task 6: Rebind menu shortcuts at runtime from persisted config

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/AppDelegateTests.swift`.

```swift
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
    #expect(openItem?.keyEquivalentModifierMask == [.command, .shift])
    #expect(toggleItem?.keyEquivalent == "t")
    #expect(toggleItem?.keyEquivalentModifierMask == [.command])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter appDelegateBuildsMenuFromConfiguredShortcuts`
Expected: FAIL because `buildMainMenu` is still hardcoded and has no config parameter.

- [ ] **Step 3: Write minimal implementation**

Refactor `Sources/mmReaderUI/AppDelegate.swift` so menu construction is config-driven.

```swift
private func buildMainMenu(config: ReaderConfig) -> NSMenu {
    let mainMenu = NSMenu()

    let fileMenuItem = NSMenuItem()
    mainMenu.addItem(fileMenuItem)
    let fileMenu = NSMenu(title: "File")
    fileMenuItem.submenu = fileMenu

    let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: config.shortcuts.openFile.key)
    openItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.openFile.modifiers)
    openItem.target = self
    fileMenu.addItem(openItem)

    let navMenuItem = NSMenuItem()
    mainMenu.addItem(navMenuItem)
    let navMenu = NSMenu(title: "Navigate")
    navMenuItem.submenu = navMenu

    let toggleToolbarItem = NSMenuItem(title: "Toggle Toolbar", action: #selector(toggleToolbar(_:)), keyEquivalent: config.shortcuts.toggleToolbar.key)
    toggleToolbarItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.toggleToolbar.modifiers)
    toggleToolbarItem.target = self
    navMenu.addItem(toggleToolbarItem)

    return mainMenu
}
```

Expose a test helper.

```swift
func debugBuildMainMenu(config: ReaderConfig) -> NSMenu {
    buildMainMenu(config: config)
}
```

Keep `applicationDidFinishLaunching` using the live config.

```swift
NSApp.mainMenu = buildMainMenu(config: controller.debugConfigForTesting)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter appDelegateBuildsMenuFromConfiguredShortcuts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: build menus from configured shortcuts"
```

---

### Task 7: Expand ShortcutSettingsView to show and edit the approved action list

**Files:**
- Modify: `Sources/mmReaderUI/ShortcutSettingsView.swift`
- Modify: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`.

```swift
@MainActor
@Test func shortcutSettingsViewListsExpandedShellActions() {
    let shortcuts = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))

    #expect(shortcuts.debugActionLabelsForTesting() == [
        "上一页",
        "下一页",
        "显隐工具栏",
        "打开文件",
        "关闭窗口",
        "显隐主窗口",
        "显隐 Controls",
        "切换置顶",
        "隐藏工具栏"
    ])
}

@MainActor
@Test func controlsApplyShowsCurrentShortcutValues() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 260, height: 260))
    let shortcuts = ReaderShortcutBindings(
        previousPage: .init(key: "upArrow"),
        nextPage: .init(key: "downArrow"),
        toggleToolbar: .init(key: "b", modifiers: ["command"]),
        openFile: .init(key: "o", modifiers: ["command"]),
        closeWindow: .init(key: "w", modifiers: ["command"]),
        toggleMainWindow: .init(key: "m", modifiers: ["command"]),
        toggleControls: .init(key: ",", modifiers: ["command"]),
        togglePin: .init(key: "p", modifiers: ["command"]),
        hideToolbar: .init(key: "h", modifiers: ["command", "shift"])
    )

    controls.apply(
        fontSize: 18,
        linesPerPage: 30,
        textAlpha: 1.0,
        backgroundAlpha: 0.85,
        shortcuts: shortcuts
    )

    #expect(controls.shortcutSettingsView.debugDisplayedBindingForTesting(action: "显隐主窗口") == "⌘M")
    #expect(controls.shortcutSettingsView.debugDisplayedBindingForTesting(action: "隐藏工具栏") == "⇧⌘H")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'shortcutSettingsViewListsExpandedShellActions|controlsApplyShowsCurrentShortcutValues'`
Expected: FAIL because the view only lists five actions and cannot render current binding values.

- [ ] **Step 3: Write minimal implementation**

Expand the action list in `Sources/mmReaderUI/ShortcutSettingsView.swift`.

```swift
private let actionLabels = [
    "上一页",
    "下一页",
    "显隐工具栏",
    "打开文件",
    "关闭窗口",
    "显隐主窗口",
    "显隐 Controls",
    "切换置顶",
    "隐藏工具栏"
]
```

Add an apply/render API.

```swift
public func apply(shortcuts: ReaderShortcutBindings) {
    displayedBindings["上一页"] = displayText(for: shortcuts.previousPage)
    displayedBindings["下一页"] = displayText(for: shortcuts.nextPage)
    displayedBindings["显隐工具栏"] = displayText(for: shortcuts.toggleToolbar)
    displayedBindings["打开文件"] = displayText(for: shortcuts.openFile)
    displayedBindings["关闭窗口"] = displayText(for: shortcuts.closeWindow)
    displayedBindings["显隐主窗口"] = displayText(for: shortcuts.toggleMainWindow)
    displayedBindings["显隐 Controls"] = displayText(for: shortcuts.toggleControls)
    displayedBindings["切换置顶"] = displayText(for: shortcuts.togglePin)
    displayedBindings["隐藏工具栏"] = displayText(for: shortcuts.hideToolbar)
}
```

Expose a test helper.

```swift
func debugDisplayedBindingForTesting(action: String) -> String {
    displayedBindings[action] ?? ""
}
```

Update `Sources/mmReaderUI/ReaderControlsPopoverView.swift` to accept shortcuts when applying state.

```swift
public func apply(fontSize: Double, linesPerPage: Int, textAlpha: Double, backgroundAlpha: Double, shortcuts: ReaderShortcutBindings) {
    fontSlider.doubleValue = fontSize
    linesSlider.doubleValue = Double(linesPerPage)
    textAlphaSlider.doubleValue = textAlpha
    backgroundAlphaSlider.doubleValue = backgroundAlpha
    shortcutSettingsView.apply(shortcuts: shortcuts)
    updateValueLabels()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'shortcutSettingsViewListsExpandedShellActions|controlsApplyShowsCurrentShortcutValues'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ShortcutSettingsView.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift
git commit -m "feat: expand shortcut settings display"
```

---

### Task 8: Connect control changes back to app-level runtime updates

**Files:**
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests.

`Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
```swift
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
```

`Tests/mmReaderCoreTests/AppDelegateTests.swift`
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'shellModeChangeNotifiesObserver|shortcutChangeNotifiesObserver|appDelegateRebuildsMainMenuAfterShortcutChange'`
Expected: FAIL because there are no app-level observer closures and shell/shortcut changes are persisted only locally.

- [ ] **Step 3: Write minimal implementation**

Add app-level callbacks in `Sources/mmReaderUI/ReaderWindowController.swift`.

```swift
public var onShellModeChangedForApp: ((ReaderShellMode) -> Void)?
public var onCloseBehaviorChangedForApp: ((ReaderCloseBehavior) -> Void)?
public var onShortcutsChangedForApp: ((ReaderShortcutBindings) -> Void)?
```

Fire them in control handlers.

```swift
contentView.controlsView.onShellModeChanged = { [weak self] mode in
    self?.controllerState.config.shellMode = mode
    self?.onShellModeChangedForApp?(mode)
    self?.persistConfigDebounced()
}

contentView.controlsView.onCloseBehaviorChanged = { [weak self] behavior in
    self?.controllerState.config.closeBehavior = behavior
    self?.onCloseBehaviorChangedForApp?(behavior)
    self?.persistConfigDebounced()
}

contentView.controlsView.shortcutSettingsView.onShortcutChanged = { [weak self] action, binding in
    self?.debugApplyShortcutForTesting(action: action, key: binding.key, modifiers: binding.modifiers)
    if let shortcuts = self?.controllerState.config.shortcuts {
        self?.onShortcutsChangedForApp?(shortcuts)
    }
    self?.persistConfigDebounced()
}
```

In `Sources/mmReaderUI/AppDelegate.swift`, observe those callbacks when the controller is created.

```swift
controller.onShellModeChangedForApp = { [weak self] mode in
    self?.apply(shellMode: mode)
}
controller.onShortcutsChangedForApp = { [weak self] shortcuts in
    guard let self, var config = self.windowController?.debugConfigForTesting else { return }
    config.shortcuts = shortcuts
    NSApp.mainMenu = self.buildMainMenu(config: config)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'shellModeChangeNotifiesObserver|shortcutChangeNotifiesObserver|appDelegateRebuildsMainMenuAfterShortcutChange'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/AppDelegateTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: propagate shell and shortcut updates to app runtime"
```

---

### Task 9: Run full verification and manual app checks

**Files:**
- Modify: any files still needed from prior tasks
- Test: full suite and app build

- [ ] **Step 1: Run targeted tests for shell/status/shortcut work**

Run: `swift test --filter 'saveThenLoadPreservesExpandedShortcutBindings|pinButtonUsesImageStateInsteadOfText|statusItemPrimaryClickTriggersToggleWindow|toggleMainWindowSwitchesWindowVisibility|closeRequestInDockOnlyHidesWindowInsteadOfQuitting|appDelegateBuildsMenuFromConfiguredShortcuts|shortcutSettingsViewListsExpandedShellActions|shellModeChangeNotifiesObserver'`
Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run: `swift test`
Expected: PASS with all tests green.

- [ ] **Step 3: Build app bundle**

Run: `bash scripts/build_app.sh`
Expected: PASS and emit `build/mmReader.app`.

- [ ] **Step 4: Manually verify shell behavior in app**

Run: `open build/mmReader.app`
Expected manual checks:
- Pin icon sits at left edge of toolbar actions and toggles between unpinned/pinned state.
- `dockOnly` hides the status item and Close leaves the app recoverable from the Dock.
- `statusItemOnly` hides the Dock, shows the status item, and left-clicking the status item toggles the window.
- `dockAndStatusItem` shows both entry points.
- Updating shortcuts in Controls changes menu shortcuts immediately.
- Triggering a few updated actions works without restarting the app.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderShortcutBinding.swift Sources/mmReaderUI/ToolbarView.swift Sources/mmReaderUI/StatusItemController.swift Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Sources/mmReaderUI/ShortcutSettingsView.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift Tests/mmReaderCoreTests/AppDelegateTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift
git commit -m "feat: finish shell status close and runtime shortcut behavior"
```
