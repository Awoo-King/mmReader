# mmReader Controls + Window Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver full reader controls (toolbar + popover), persist all settings, and fix click-through/drag/resize window behavior while preserving current reading shortcuts.

**Architecture:** Keep `ReaderWindowController` as orchestration center, expand `ToolbarView` to dispatch user actions, and add a focused controls popover component for parameter editing. Move window base from pure `.borderless` behavior to an interactive AppKit window configuration that still looks minimal/transparent. Persist all UI/control state through `ReaderConfig` + existing `ConfigStore` pipeline.

**Tech Stack:** Swift 6.3, AppKit, UniformTypeIdentifiers, Swift Testing (`import Testing`), existing mmReaderCore/mmReaderUI modules.

---

## File structure map (before tasks)

- **Modify:** `Sources/mmReaderCore/ReaderConfig.swift`
  - Add persistent `isToolbarVisible` field with default value.
- **Modify:** `Sources/mmReaderUI/ReaderWindowFactory.swift`
  - Change window style/flags to interactive + resizable while preserving minimal transparent look.
- **Modify:** `Sources/mmReaderUI/WindowAppearanceConfigurator.swift`
  - Apply window-level appearance/interaction attributes from config (`isPinned`, transparency-safe behavior).
- **Modify:** `Sources/mmReaderUI/ReaderView.swift`
  - Add APIs to apply font size/text alpha and optional drag-friendly behavior in reading surface.
- **Modify:** `Sources/mmReaderUI/ToolbarView.swift`
  - Add buttons + callbacks while preserving progress label.
- **Create:** `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
  - Encapsulate font size / lines per page / text alpha / bg alpha controls.
- **Modify:** `Sources/mmReaderUI/ReaderWindowContentView.swift`
  - Host toolbar + reader + popover anchor, keep drop support.
- **Modify:** `Sources/mmReaderUI/ReaderWindowController.swift`
  - Wire toolbar actions, popover control events, persistence, and apply config to view/window.
- **Modify:** `Sources/mmReaderUI/AppDelegate.swift`
  - Keep menu shortcuts stable; ensure `⌘B` behavior aligns with persisted toolbar visibility.
- **Modify tests:**
  - `Tests/mmReaderCoreTests/ReaderWindowFactoryTests.swift`
  - `Tests/mmReaderCoreTests/WindowAppearanceConfiguratorTests.swift`
  - `Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
  - `Tests/mmReaderCoreTests/AppDelegateTests.swift`
  - `Tests/mmReaderCoreTests/ConfigStoreTests.swift` (if needed for new config field behavior)

---

### Task 1: Persist toolbar visibility and control state in config

**Files:**
- Modify: `Sources/mmReaderCore/ReaderConfig.swift`
- Test: `Tests/mmReaderCoreTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing config persistence test for toolbar visibility**

```swift
@Test func saveThenLoadPreservesToolbarVisibility() {
    var cfg = ReaderConfig.default
    cfg.isToolbarVisible = false

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    store.save(cfg)

    let loaded = store.load()
    #expect(loaded.isToolbarVisible == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter saveThenLoadPreservesToolbarVisibility`
Expected: FAIL because `ReaderConfig` has no `isToolbarVisible`.

- [ ] **Step 3: Add `isToolbarVisible` to ReaderConfig with default true**

```swift
public var isToolbarVisible: Bool

public static let `default` = ReaderConfig(
    fontSize: 18,
    bgAlpha: 0.85,
    textAlpha: 1.0,
    linesPerPage: 30,
    windowX: 120,
    windowY: 120,
    windowWidth: 680,
    windowHeight: 840,
    isPinned: false,
    isFullscreen: false,
    lastFilePath: nil,
    lastPageIndex: 0,
    lastAnchor: nil,
    isToolbarVisible: true
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter saveThenLoadPreservesToolbarVisibility`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderConfig.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift
git commit -m "feat: persist toolbar visibility in reader config"
```

---

### Task 2: Switch window base to interactive non-click-through and resizable

**Files:**
- Modify: `Sources/mmReaderUI/ReaderWindowFactory.swift`
- Modify: `Sources/mmReaderUI/WindowAppearanceConfigurator.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowFactoryTests.swift`
- Test: `Tests/mmReaderCoreTests/WindowAppearanceConfiguratorTests.swift`

- [ ] **Step 1: Write failing tests for interactive/resizable style**

```swift
@Test func windowFactoryCreatesResizableInteractiveWindow() {
    let window = ReaderWindowFactory.makeWindow(config: .default)

    #expect(window.styleMask.contains(.titled))
    #expect(window.styleMask.contains(.resizable))
    #expect(window.styleMask.contains(.fullSizeContentView))
}

@Test func windowAppearanceDisablesMousePassThrough() {
    let window = ReaderWindowFactory.makeWindow(config: .default)
    WindowAppearanceConfigurator.apply(to: window, isPinned: false)

    #expect(window.ignoresMouseEvents == false)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter 'windowFactoryCreatesResizableInteractiveWindow|windowAppearanceDisablesMousePassThrough'`
Expected: FAIL with missing style mask expectations.

- [ ] **Step 3: Implement interactive window style and appearance**

```swift
ReaderWindow(
    contentRect: ...,
    styleMask: [.titled, .fullSizeContentView, .resizable, .miniaturizable, .closable],
    backing: .buffered,
    defer: false
)

window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true
window.isMovableByWindowBackground = true
window.ignoresMouseEvents = false
window.isOpaque = false
window.backgroundColor = .clear
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter 'windowFactoryCreatesResizableInteractiveWindow|windowAppearanceDisablesMousePassThrough'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderWindowFactory.swift Sources/mmReaderUI/WindowAppearanceConfigurator.swift Tests/mmReaderCoreTests/ReaderWindowFactoryTests.swift Tests/mmReaderCoreTests/WindowAppearanceConfiguratorTests.swift
git commit -m "fix: use interactive resizable window foundation"
```

---

### Task 3: Expand toolbar UI with core buttons and callbacks

**Files:**
- Modify: `Sources/mmReaderUI/ToolbarView.swift`
- Test: `Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`

- [ ] **Step 1: Write failing test for toolbar action callbacks**

```swift
@Test func toolbarInvokesOpenControlsPinHideCallbacks() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))
    var open = 0
    var controls = 0
    var pin = 0
    var hide = 0

    toolbar.onOpen = { open += 1 }
    toolbar.onShowControls = { controls += 1 }
    toolbar.onTogglePin = { pin += 1 }
    toolbar.onHideToolbar = { hide += 1 }

    toolbar.debugTriggerOpenForTesting()
    toolbar.debugTriggerShowControlsForTesting()
    toolbar.debugTriggerTogglePinForTesting()
    toolbar.debugTriggerHideToolbarForTesting()

    #expect(open == 1)
    #expect(controls == 1)
    #expect(pin == 1)
    #expect(hide == 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter toolbarInvokesOpenControlsPinHideCallbacks`
Expected: FAIL due to missing callbacks/debug triggers.

- [ ] **Step 3: Implement minimal toolbar buttons + callback plumbing**

```swift
public var onOpen: (() -> Void)?
public var onShowControls: (() -> Void)?
public var onTogglePin: (() -> Void)?
public var onHideToolbar: (() -> Void)?

@objc private func openTapped() { onOpen?() }
@objc private func controlsTapped() { onShowControls?() }
@objc private func pinTapped() { onTogglePin?() }
@objc private func hideTapped() { onHideToolbar?() }
```

- [ ] **Step 4: Run test to verify pass**

Run: `swift test --filter toolbarInvokesOpenControlsPinHideCallbacks`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ToolbarView.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift Tests/mmReaderCoreTests/ToolbarTransparencyTests.swift
git commit -m "feat: add toolbar action surface and callbacks"
```

---

### Task 4: Add controls popover component

**Files:**
- Create: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`

- [ ] **Step 1: Write failing test for controls change callbacks**

```swift
@Test func controlsPopoverEmitsValueChanges() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 260, height: 180))
    var lastFont: Double = 0
    var lastLines: Int = 0
    var lastTextAlpha: Double = 0
    var lastBgAlpha: Double = 0

    controls.onFontSizeChanged = { lastFont = $0 }
    controls.onLinesPerPageChanged = { lastLines = $0 }
    controls.onTextAlphaChanged = { lastTextAlpha = $0 }
    controls.onBackgroundAlphaChanged = { lastBgAlpha = $0 }

    controls.debugSetFontSizeForTesting(22)
    controls.debugSetLinesPerPageForTesting(35)
    controls.debugSetTextAlphaForTesting(0.8)
    controls.debugSetBackgroundAlphaForTesting(0.6)

    #expect(lastFont == 22)
    #expect(lastLines == 35)
    #expect(lastTextAlpha == 0.8)
    #expect(lastBgAlpha == 0.6)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter controlsPopoverEmitsValueChanges`
Expected: FAIL because component not created.

- [ ] **Step 3: Implement minimal popover view with sliders/steppers and callbacks**

```swift
public final class ReaderControlsPopoverView: NSView {
    public var onFontSizeChanged: ((Double) -> Void)?
    public var onLinesPerPageChanged: ((Int) -> Void)?
    public var onTextAlphaChanged: ((Double) -> Void)?
    public var onBackgroundAlphaChanged: ((Double) -> Void)?
    // controls + target/actions
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `swift test --filter controlsPopoverEmitsValueChanges`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift
git commit -m "feat: add reader controls popover component"
```

---

### Task 5: Wire controller orchestration for controls, persistence, and toolbar visibility

**Files:**
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowContentView.swift`
- Modify: `Sources/mmReaderUI/ToolbarVisibilityController.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderControllerStateFlowTests.swift`

- [ ] **Step 1: Write failing tests for config mutation + persistence triggers**

```swift
@Test func toggleToolbarPersistsVisibilityState() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ConfigStore(baseURL: root)
    let wc = ReaderWindowController(configStore: store)

    wc.toggleToolbar()
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.isToolbarVisible == false)
}

@Test func applyingControlValuesUpdatesConfig() {
    let wc = ReaderWindowController(configStore: ConfigStore())

    wc.debugApplyFontSizeForTesting(24)
    wc.debugApplyLinesPerPageForTesting(40)
    wc.debugApplyTextAlphaForTesting(0.75)
    wc.debugApplyBackgroundAlphaForTesting(0.5)

    #expect(wc.debugConfigForTesting.fontSize == 24)
    #expect(wc.debugConfigForTesting.linesPerPage == 40)
    #expect(wc.debugConfigForTesting.textAlpha == 0.75)
    #expect(wc.debugConfigForTesting.bgAlpha == 0.5)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter 'toggleToolbarPersistsVisibilityState|applyingControlValuesUpdatesConfig'`
Expected: FAIL due to missing APIs/wiring.

- [ ] **Step 3: Implement minimal controller wiring**

```swift
contentView.toolbarView.onOpen = { [weak self] in self?.presentOpenPanel() }
contentView.toolbarView.onShowControls = { [weak self] in self?.toggleControlsPopover() }
contentView.toolbarView.onTogglePin = { [weak self] in self?.togglePinState() }
contentView.toolbarView.onHideToolbar = { [weak self] in self?.setToolbarVisible(false) }

private func setToolbarVisible(_ visible: Bool) {
    toolbarVisibilityController.setVisible(visible)
    controllerState.config.isToolbarVisible = visible
    persistConfigDebounced()
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter 'toggleToolbarPersistsVisibilityState|applyingControlValuesUpdatesConfig'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderWindowController.swift Sources/mmReaderUI/ReaderWindowContentView.swift Sources/mmReaderUI/ToolbarVisibilityController.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift Tests/mmReaderCoreTests/ReaderControllerStateFlowTests.swift
git commit -m "feat: wire controls and persist reader ui state"
```

---

### Task 6: Apply presentation controls to ReaderView and window appearance

**Files:**
- Modify: `Sources/mmReaderUI/ReaderView.swift`
- Modify: `Sources/mmReaderUI/WindowAppearanceConfigurator.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift`
- Test: `Tests/mmReaderCoreTests/WindowAppearanceConfiguratorTests.swift`

- [ ] **Step 1: Write failing tests for font/text alpha/bg alpha application**

```swift
@Test func readerViewAppliesFontAndTextAlpha() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))

    view.applyFontSize(26)
    view.applyTextAlpha(0.7)

    #expect(view.debugFontSizeForTesting == 26)
    #expect(view.debugTextAlphaForTesting == 0.7)
}

@Test func windowAppearanceAppliesBackgroundAlpha() {
    let window = ReaderWindowFactory.makeWindow(config: .default)
    WindowAppearanceConfigurator.applyBackgroundAlpha(0.4, to: window)

    #expect(window.alphaValue == 1.0)
    #expect(window.backgroundColor.alphaComponent == 0.4)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter 'readerViewAppliesFontAndTextAlpha|windowAppearanceAppliesBackgroundAlpha'`
Expected: FAIL due to missing APIs.

- [ ] **Step 3: Implement minimal apply methods and controller calls**

```swift
public func applyFontSize(_ size: Double) {
    textView.font = NSFont.systemFont(ofSize: size)
}

public func applyTextAlpha(_ alpha: Double) {
    textView.textColor = NSColor.black.withAlphaComponent(alpha)
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter 'readerViewAppliesFontAndTextAlpha|windowAppearanceAppliesBackgroundAlpha'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderView.swift Sources/mmReaderUI/WindowAppearanceConfigurator.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift Tests/mmReaderCoreTests/WindowAppearanceConfiguratorTests.swift
git commit -m "feat: apply font and transparency controls to reader"
```

---

### Task 7: Preserve shortcut behavior and add full integration verification tests

**Files:**
- Modify: `Sources/mmReaderUI/AppDelegate.swift`
- Test: `Tests/mmReaderCoreTests/AppDelegateTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write failing tests for `⌘B` restore flow and menu stability**

```swift
@Test func commandBRestoresToolbarAfterHide() {
    let wc = ReaderWindowController(configStore: ConfigStore())

    wc.toggleToolbar()   // hide
    #expect(wc.isToolbarVisible == false)

    wc.toggleToolbar()   // show
    #expect(wc.isToolbarVisible == true)
}

@Test func appDelegateKeepsOpenAndPagingShortcuts() {
    let delegate = AppDelegate()
    let menu = delegate.debugBuildMainMenu()
    let fileMenu = menu.items[1].submenu
    let navMenu = menu.items[2].submenu

    #expect(fileMenu?.items.contains(where: { $0.keyEquivalent == "o" }) == true)
    #expect(navMenu?.items.contains(where: { $0.keyEquivalent == "[" }) == true)
    #expect(navMenu?.items.contains(where: { $0.keyEquivalent == "]" }) == true)
    #expect(navMenu?.items.contains(where: { $0.keyEquivalent == "b" }) == true)
}
```

- [ ] **Step 2: Run tests to verify failure (if behavior not wired) or keep as regression lock**

Run: `swift test --filter 'commandBRestoresToolbarAfterHide|appDelegateKeepsOpenAndPagingShortcuts'`
Expected: Initially FAIL if wiring incomplete; otherwise PASS and remain as regression coverage.

- [ ] **Step 3: Implement only missing shortcut/menu behavior**

```swift
// Keep AppDelegate menu wiring for:
// openDocument, nextPage, previousPage, toggleToolbar
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test --filter 'commandBRestoresToolbarAfterHide|appDelegateKeepsOpenAndPagingShortcuts'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/AppDelegate.swift Tests/mmReaderCoreTests/AppDelegateTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
git commit -m "test: lock shortcut and toolbar restore behavior"
```

---

### Task 8: Final verification + package validation

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
- no click-through to background
- drag from toolbar works
- drag from reader area works
- resize from edges/corners works
- `⌘O`, `[`, `]`, `⌘B` all work
- toolbar buttons (Open/Controls/Pin/Hide) work
- font/lines/text/bg controls apply instantly
- relaunch restores all persisted settings

- [ ] **Step 5: Commit final polish (if any fixes needed)**

```bash
git add Sources/mmReaderCore/ReaderConfig.swift Sources/mmReaderUI/ReaderWindowFactory.swift Sources/mmReaderUI/WindowAppearanceConfigurator.swift Sources/mmReaderUI/ReaderView.swift Sources/mmReaderUI/ToolbarView.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Sources/mmReaderUI/ReaderWindowContentView.swift Sources/mmReaderUI/ReaderWindowController.swift Sources/mmReaderUI/AppDelegate.swift Tests/mmReaderCoreTests/*.swift
git commit -m "feat: complete reader controls and stable interactive window behavior"
```

---

## Self-review checklist (spec coverage)

- Controls panel strategy (toolbar + popover): covered by Tasks 3-5.
- Required controls (font size, lines/page, text darkness, bg transparency): covered by Tasks 4-6.
- Pin/open/hide actions: covered by Tasks 3, 5, 7.
- Persist all settings including toolbar visibility: covered by Tasks 1 and 5.
- Eliminate click-through and support drag/resize: covered by Task 2 + manual checks in Task 8.
- Preserve shortcuts (`⌘O`, `[`, `]`, `⌘B`): covered by Task 7.
- Build and test verification on packaged app: covered by Task 8.

No placeholders remain. Type/property names are consistent with existing code and newly introduced fields.
