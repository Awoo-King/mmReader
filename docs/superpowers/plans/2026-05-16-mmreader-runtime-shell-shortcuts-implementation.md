# mmReader Runtime Shell + Shortcut Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable Dock/status-bar presence, configurable close-window behavior, simple shortcut settings for core actions, and updated paging/pin interactions while preserving current reader controls and stable window behavior.

**Architecture:** Extend `ReaderConfig` to persist runtime shell mode, close behavior, and simple shortcut bindings. Keep `ReaderWindowController` as orchestration center, add a dedicated status-item coordinator for NSStatusItem behavior, and centralize keyboard/menu binding resolution so menus, runtime handlers, and future settings all share one config-driven source of truth.

**Tech Stack:** Swift 6.3, AppKit, UniformTypeIdentifiers, Swift Testing (`import Testing`), existing mmReaderCore/mmReaderUI modules.

---

## File structure map (before tasks)

- **Modify:** `Sources/mmReaderCore/ReaderConfig.swift`
  - Add persistent shell mode, close behavior, and simple shortcut bindings.
- **Create:** `Sources/mmReaderCore/ReaderShellMode.swift`
  - Enum for `dockOnly`, `statusItemOnly`, `dockAndStatusItem`.
- **Create:** `Sources/mmReaderCore/ReaderCloseBehavior.swift`
  - Enum for `hideWindow` vs `quitApp`.
- **Create:** `Sources/mmReaderCore/ReaderShortcutBinding.swift`
  - Codable mapping for core actions to keys.
- **Create:** `Sources/mmReaderUI/StatusItemController.swift`
  - Own `NSStatusItem`, click toggle, and menu actions.
- **Modify:** `Sources/mmReaderUI/AppDelegate.swift`
  - Move hardcoded menu shortcuts to config-driven values and coordinate close behavior/runtime shell mode.
- **Modify:** `Sources/mmReaderUI/ReaderWindowController.swift`
  - Apply runtime shell settings, expose show/hide window behavior, update pin label state, and support arrow-key paging.
- **Modify:** `Sources/mmReaderUI/ToolbarView.swift`
  - Pin button title becomes stateful Chinese text.
- **Modify:** `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
  - Add shell mode selector, close behavior selector, and simple shortcut editor fields.
- **Create:** `Sources/mmReaderUI/ShortcutSettingsView.swift`
  - Focused simple shortcut editor for core actions.
- **Modify:** `Sources/mmReaderUI/ReaderWindowContentView.swift`
  - Host shortcut settings subview or settings section alongside controls.
- **Tests to modify/add:**
  - `Tests/mmReaderCoreTests/AppDelegateTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
  - `Tests/mmReaderCoreTests/ConfigStoreTests.swift`
  - new tests for status item + shell mode config under `Tests/mmReaderCoreTests/`

---

### Task 1: Persist runtime shell mode, close behavior, and shortcut bindings

**Files:**
- Create: `Sources/mmReaderCore/ReaderShellMode.swift`
- Create: `Sources/mmReaderCore/ReaderCloseBehavior.swift`
- Create: `Sources/mmReaderCore/ReaderShortcutBinding.swift`
- Modify: `Sources/mmReaderCore/ReaderConfig.swift`
- Test: `Tests/mmReaderCoreTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing persistence test for new runtime fields**

```swift
@Test func saveThenLoadPreservesShellModeCloseBehaviorAndShortcuts() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.shellMode = .statusItemOnly
    cfg.closeBehavior = .quitApp
    cfg.shortcuts.nextPage = .downArrow
    cfg.shortcuts.previousPage = .upArrow
    cfg.shortcuts.closeWindow = .key("w", modifiers: [.command])

    store.save(cfg)
    let loaded = store.load()

    #expect(loaded.shellMode == .statusItemOnly)
    #expect(loaded.closeBehavior == .quitApp)
    #expect(loaded.shortcuts.nextPage == .downArrow)
    #expect(loaded.shortcuts.previousPage == .upArrow)
    #expect(loaded.shortcuts.closeWindow == .key("w", modifiers: [.command]))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter saveThenLoadPreservesShellModeCloseBehaviorAndShortcuts`
Expected: FAIL because new types/fields do not exist.

- [ ] **Step 3: Add enums and shortcut binding model, then wire into ReaderConfig**

```swift
public enum ReaderShellMode: String, Codable, Equatable, Sendable {
    case dockOnly
    case statusItemOnly
    case dockAndStatusItem
}

public enum ReaderCloseBehavior: String, Codable, Equatable, Sendable {
    case hideWindow
    case quitApp
}

public struct ReaderShortcutBindings: Codable, Equatable, Sendable {
    public var previousPage: ReaderShortcutBinding
    public var nextPage: ReaderShortcutBinding
    public var toggleToolbar: ReaderShortcutBinding
    public var openFile: ReaderShortcutBinding
    public var closeWindow: ReaderShortcutBinding
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter saveThenLoadPreservesShellModeCloseBehaviorAndShortcuts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderShellMode.swift Sources/mmReaderCore/ReaderCloseBehavior.swift Sources/mmReaderCore/ReaderShortcutBinding.swift Sources/mmReaderCore/ReaderConfig.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift
git commit -m "feat: persist shell mode close behavior and shortcuts"
```

---

### Task 2: Move paging from bracket keys to arrow keys

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write failing tests for arrow-key paging menu bindings**

```swift
@Test func appDelegateBuildsArrowPagingShortcuts() {
    let delegate = AppDelegate()
    let menu = delegate.debugBuildMainMenu()
    let navMenu = menu.items[2].submenu

    let nextItem = navMenu?.items.first(where: { $0.title == "Next Page" })
    let prevItem = navMenu?.items.first(where: { $0.title == "Previous Page" })

    #expect(nextItem?.keyEquivalent == NSUpArrowFunctionKey.description)
    #expect(prevItem?.keyEquivalent == NSDownArrowFunctionKey.description)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter appDelegateBuildsArrowPagingShortcuts`
Expected: FAIL because current bindings still use `[` and `]`.

- [ ] **Step 3: Update menu creation to use config-driven arrow defaults**

```swift
let nextItem = NSMenuItem(title: "Next Page", action: #selector(nextPage(_:)), keyEquivalent: String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)))
let prevItem = NSMenuItem(title: "Previous Page", action: #selector(previousPage(_:)), keyEquivalent: String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter appDelegateBuildsArrowPagingShortcuts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: use arrow keys for paging shortcuts"
```

---

### Task 3: Make pin button label reflect state

**Files:**
- Modify: `Sources/mmReaderUI/ToolbarView.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write failing tests for pin title state**

```swift
@Test func toolbarShowsPinnedAndUnpinnedTitles() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))

    toolbar.setPinned(false)
    #expect(toolbar.debugPinTitleForTesting == "置顶")

    toolbar.setPinned(true)
    #expect(toolbar.debugPinTitleForTesting == "取消置顶")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter toolbarShowsPinnedAndUnpinnedTitles`
Expected: FAIL because `setPinned` and debug title accessor do not exist.

- [ ] **Step 3: Implement toolbar title update API and controller wiring**

```swift
public func setPinned(_ pinned: Bool) {
    pinButton.title = pinned ? "取消置顶" : "置顶"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter toolbarShowsPinnedAndUnpinnedTitles`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ToolbarView.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: reflect pin state in toolbar label"
```

---

### Task 4: Add status item coordinator with click toggle and menu actions

**Files:**
- Create: `Sources/mmReaderUI/StatusItemController.swift`
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write failing test for status item menu shape**

```swift
@Test func statusItemControllerBuildsRequiredMenuItems() {
    let controller = StatusItemController()
    let menu = controller.debugMenuForTesting()
    let titles = menu.items.map(\.title)

    #expect(titles.contains("显示窗口"))
    #expect(titles.contains("隐藏窗口"))
    #expect(titles.contains("置顶"))
    #expect(titles.contains("打开文件"))
    #expect(titles.contains("退出"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter statusItemControllerBuildsRequiredMenuItems`
Expected: FAIL because status item controller does not exist.

- [ ] **Step 3: Implement minimal status item controller**

```swift
public final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    public var onToggleWindow: (() -> Void)?
    public var onShowWindow: (() -> Void)?
    public var onHideWindow: (() -> Void)?
    public var onTogglePin: (() -> Void)?
    public var onOpenFile: (() -> Void)?
    public var onQuit: (() -> Void)?
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter statusItemControllerBuildsRequiredMenuItems`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/StatusItemController.swift Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/AppDelegateTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "feat: add status item controller and actions"
```

---

### Task 5: Add runtime shell mode handling for Dock/status bar presence

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Modify: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write failing test for shell mode application**

```swift
@Test func appDelegateAppliesShellModePresentationPolicy() {
    let delegate = AppDelegate()

    #expect(delegate.debugActivationPolicy(for: .dockOnly) == .regular)
    #expect(delegate.debugActivationPolicy(for: .statusItemOnly) == .accessory)
    #expect(delegate.debugActivationPolicy(for: .dockAndStatusItem) == .regular)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter appDelegateAppliesShellModePresentationPolicy`
Expected: FAIL because helper/policy does not exist.

- [ ] **Step 3: Implement minimal activation policy + status item visibility logic**

```swift
func apply(shellMode: ReaderShellMode) {
    switch shellMode {
    case .dockOnly:
        NSApp.setActivationPolicy(.regular)
        statusItemController.setVisible(false)
    case .statusItemOnly:
        NSApp.setActivationPolicy(.accessory)
        statusItemController.setVisible(true)
    case .dockAndStatusItem:
        NSApp.setActivationPolicy(.regular)
        statusItemController.setVisible(true)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter appDelegateAppliesShellModePresentationPolicy`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: add configurable dock and status item modes"
```

---

### Task 6: Add configurable close-window behavior

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write failing test for close behavior routing**

```swift
@Test func closeBehaviorCanResolveToHideOrQuit() {
    let delegate = AppDelegate()

    #expect(delegate.debugShouldQuitOnClose(.hideWindow) == false)
    #expect(delegate.debugShouldQuitOnClose(.quitApp) == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter closeBehaviorCanResolveToHideOrQuit`
Expected: FAIL because close behavior resolution does not exist.

- [ ] **Step 3: Implement minimal close behavior handling**

```swift
func shouldQuitOnClose(_ behavior: ReaderCloseBehavior) -> Bool {
    behavior == .quitApp
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter closeBehaviorCanResolveToHideOrQuit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: add configurable close window behavior"
```

---

### Task 7: Add simple shortcut settings surface for core actions

**Files:**
- Create: `Sources/mmReaderUI/ShortcutSettingsView.swift`
- Modify: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`

- [ ] **Step 1: Write failing test for shortcut settings surface**

```swift
@Test func shortcutSettingsShowsCoreActions() {
    let view = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 320, height: 220))
    let labels = view.debugActionLabelsForTesting()

    #expect(labels.contains("上一页"))
    #expect(labels.contains("下一页"))
    #expect(labels.contains("显隐工具栏"))
    #expect(labels.contains("打开文件"))
    #expect(labels.contains("关闭窗口"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter shortcutSettingsShowsCoreActions`
Expected: FAIL because settings view does not exist.

- [ ] **Step 3: Implement minimal simple shortcut settings view and embed it**

```swift
public final class ShortcutSettingsView: NSView {
    public var onShortcutChanged: ((ReaderShortcutAction, ReaderShortcutBinding) -> Void)?
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter shortcutSettingsShowsCoreActions`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ShortcutSettingsView.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Sources/mmReaderUI/AppDelegate.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift Tests/mmReaderCoreTests/AppDelegateTests.swift
git commit -m "feat: add simple shortcut settings surface"
```

---

### Task 8: Final verification + packaged app validation

**Files:**
- Modify (if needed): any failing file from prior tasks
- Verify: `scripts/build_app.sh`

- [ ] **Step 1: Run full tests**

Run: `swift test`
Expected: PASS with 0 failures.

- [ ] **Step 2: Build app bundle**

Run: `bash scripts/build_app.sh`
Expected: `Built: /Users/awoo/Desktop/mmReader/build/mmReader.app`

- [ ] **Step 3: Verify built artifact timestamp changed**

Run: `ls -lT build/mmReader.app/Contents/MacOS/mmReader build/mmReader.app/Contents/Info.plist`
Expected: timestamps reflect current run.

- [ ] **Step 4: Manual verification checklist on built app**

Run app and verify:
- status item click toggles main window
- status item menu supports show/hide, pin/unpin, open file, quit
- Dock/status item mode switch works for all 3 modes
- close-window mode hides or quits according to setting
- `↑` and `↓` page correctly
- pin button text flips between `置顶` and `取消置顶`
- shortcut settings can change core keybindings
- reader controls still update and persist
- no click-through regression
- drag/resize still work

- [ ] **Step 5: Commit final polish (if any fixes needed)**

```bash
git add Sources/mmReaderCore/*.swift Sources/mmReaderUI/*.swift Tests/mmReaderCoreTests/*.swift
git commit -m "feat: add runtime shell modes and shortcut settings"
```

---

## Self-review checklist (spec coverage)

- Arrow-key paging: covered by Task 2.
- Pin label state change: covered by Task 3.
- Status item click + menu: covered by Task 4.
- Dock/status item 3-mode runtime shell: covered by Task 5.
- Close-window configurable behavior: covered by Task 6.
- Simple shortcut settings for core actions: covered by Task 7.
- Persistence of new settings: covered by Task 1.
- Final packaged app validation: covered by Task 8.

No placeholders remain. New types and responsibilities are named explicitly and mapped to files/tasks.
