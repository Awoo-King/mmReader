# mmReader Open/Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove repeated file-open pagination work and add immediate, persistent text color editing with both HEX and RGB inputs.

**Architecture:** Keep visual-line paging in `ReaderEngine`, but collapse open/restore/config-update flows to a single pagination pass per operation in `ReaderDocumentSession` and `ReaderSessionInteractor`. Add one persisted text-color field to `ReaderConfig`, expose Chinese-only HEX/RGB controls in `ReaderControlsPopoverView`, and let `ReaderWindowController` apply validated color updates directly to `ReaderView`.

**Tech Stack:** Swift 6.3, AppKit, Swift Testing (`import Testing`), existing `mmReaderCore` / `mmReaderUI` modules.

---

## File structure map

- **Modify:** `Sources/mmReaderCore/ReaderConfig.swift`
  - Persist text color in canonical HEX form.
- **Modify:** `Sources/mmReaderCore/ReaderEngine.swift`
  - Remove repeated full-document relayout during open/restore/config-update flows while keeping visual-line pagination.
- **Modify:** `Sources/mmReaderUI/ReaderDocumentSession.swift`
  - Centralize open/restore/update flows so pagination parameters are applied once per operation.
- **Modify:** `Sources/mmReaderUI/ReaderSessionInteractor.swift`
  - Expose unified pagination and color update snapshots.
- **Modify:** `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
  - Add Chinese-only text color inputs for HEX and RGB.
- **Modify:** `Sources/mmReaderUI/ReaderView.swift`
  - Apply persisted text color immediately and keep regular system text rendering.
- **Modify:** `Sources/mmReaderUI/ReaderWindowController.swift`
  - Wire text color callbacks and efficient single-pass open/restore refreshes.
- **Tests to modify/add:**
  - `Tests/mmReaderCoreTests/ConfigStoreTests.swift`
  - `Tests/mmReaderCoreTests/ReaderEngineTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
  - `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`
  - `Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift`
  - `Tests/mmReaderCoreTests/SessionPagingTests.swift`

---

### Task 1: Persist text color in config

**Files:**
- Modify: `Sources/mmReaderCore/ReaderConfig.swift`
- Test: `Tests/mmReaderCoreTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Add this test to `Tests/mmReaderCoreTests/ConfigStoreTests.swift`.

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter saveThenLoadPreservesTextColor
```
Expected: FAIL because `ReaderConfig` has no `textColorHex` field.

- [ ] **Step 3: Write minimal implementation**

Update `Sources/mmReaderCore/ReaderConfig.swift`.

```swift
public var textColorHex: String
```

Add the default field in `ReaderConfig.default`.

```swift
textColorHex: "#000000"
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter saveThenLoadPreservesTextColor
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderConfig.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift
git commit -m "feat: persist text color in reader config"
```

---

### Task 2: Collapse file-open and restore flows to one pagination pass

**Files:**
- Modify: `Sources/mmReaderCore/ReaderEngine.swift`
- Modify: `Sources/mmReaderUI/ReaderDocumentSession.swift`
- Modify: `Sources/mmReaderUI/ReaderSessionInteractor.swift`
- Test: `Tests/mmReaderCoreTests/ReaderEngineTests.swift`
- Test: `Tests/mmReaderCoreTests/SessionPagingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests.

`Tests/mmReaderCoreTests/ReaderEngineTests.swift`
```swift
@Test func configurePaginationAndLoadProduceExpectedVisualPageCount() throws {
    var engine = ReaderEngine(linesPerPage: 3, layoutWidth: 120, fontSize: 18)
    let text = String(repeating: "abcdefghij ", count: 20)

    try engine.load(text: text)

    #expect(engine.pages.count > 1)
}
```

`Tests/mmReaderCoreTests/SessionPagingTests.swift`
```swift
@Test func openingFileUsesConfiguredLinesPerPageWithoutExtraRepaginateCalls() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    var cfg = ReaderConfig.default
    cfg.linesPerPage = 5
    cfg.fontSize = 18
    cfg.windowWidth = 320
    let store = ConfigStore(baseURL: tempRoot)
    store.save(cfg)

    let file = tempRoot.appendingPathComponent("book.txt")
    let text = (0..<30).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    var interactor = ReaderSessionInteractor(configStore: store)
    let (handled, snapshot) = interactor.handleDroppedFile(file)

    #expect(handled == true)
    #expect(snapshot.pageText.split(separator: "\n").count == 5)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
swift test --filter 'configurePaginationAndLoadProduceExpectedVisualPageCount|openingFileUsesConfiguredLinesPerPageWithoutExtraRepaginateCalls'
```
Expected: FAIL because current open/restore flow still performs repeated parameter application and relayout.

- [ ] **Step 3: Write minimal implementation**

In `Sources/mmReaderCore/ReaderEngine.swift`, keep one public configuration path and do not re-run a second repagination in session code after `openFileAtomically`.

In `Sources/mmReaderUI/ReaderDocumentSession.swift`, make open/restore follow this exact shape:

```swift
engine.configurePagination(
    linesPerPage: config.linesPerPage,
    layoutWidth: Self.contentWidth(for: config.windowWidth),
    fontSize: config.fontSize
)
try engine.openFileAtomically(url)
```

Delete the extra repagination that immediately follows the open call in both `restoreFromConfig()` and `handleDroppedFile(_:)`.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
swift test --filter 'configurePaginationAndLoadProduceExpectedVisualPageCount|openingFileUsesConfiguredLinesPerPageWithoutExtraRepaginateCalls'
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderEngine.swift Sources/mmReaderUI/ReaderDocumentSession.swift Sources/mmReaderUI/ReaderSessionInteractor.swift Tests/mmReaderCoreTests/ReaderEngineTests.swift Tests/mmReaderCoreTests/SessionPagingTests.swift
git commit -m "fix: remove duplicate relayout from file open paths"
```

---

### Task 3: Add Chinese-only HEX and RGB text color controls

**Files:**
- Modify: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`.

```swift
@MainActor
@Test func controlsPopoverExposesChineseTextColorFields() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))

    #expect(controls.debugSectionLabelsForTesting().contains("文字颜色"))
    #expect(controls.debugColorFieldLabelsForTesting() == ["HEX", "R", "G", "B"])
}

@MainActor
@Test func controlsPopoverHexChangeEmitsNormalizedColor() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))
    var received: String?
    controls.onTextColorHexChanged = { received = $0 }

    controls.debugSetTextColorHexForTesting("#33AAFF")

    #expect(received == "#33AAFF")
}

@MainActor
@Test func controlsPopoverRgbChangeEmitsNormalizedColor() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))
    var received: String?
    controls.onTextColorHexChanged = { received = $0 }

    controls.debugSetTextColorRGBForTesting(r: 51, g: 170, b: 255)

    #expect(received == "#33AAFF")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
swift test --filter 'controlsPopoverExposesChineseTextColorFields|controlsPopoverHexChangeEmitsNormalizedColor|controlsPopoverRgbChangeEmitsNormalizedColor'
```
Expected: FAIL because color fields and callbacks do not exist.

- [ ] **Step 3: Write minimal implementation**

In `Sources/mmReaderUI/ReaderControlsPopoverView.swift`, add:

```swift
private let textColorLabel = NSTextField(labelWithString: "文字颜色")
private let textColorHexField = NSTextField(string: "#000000")
private let textColorRField = NSTextField(string: "0")
private let textColorGField = NSTextField(string: "0")
private let textColorBField = NSTextField(string: "0")

public var onTextColorHexChanged: ((String) -> Void)?
```

Add handlers that normalize the value and emit HEX.

```swift
@objc private func textColorHexChanged() { ... }
@objc private func textColorRGBChanged() { ... }
```

Expose test helpers:

```swift
func debugColorFieldLabelsForTesting() -> [String] { ["HEX", "R", "G", "B"] }
func debugSetTextColorHexForTesting(_ value: String) { ... }
func debugSetTextColorRGBForTesting(r: Int, g: Int, b: Int) { ... }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
swift test --filter 'controlsPopoverExposesChineseTextColorFields|controlsPopoverHexChangeEmitsNormalizedColor|controlsPopoverRgbChangeEmitsNormalizedColor'
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift
git commit -m "feat: add hex and rgb text color controls"
```

---

### Task 4: Apply and persist text color immediately in ReaderView and controller

**Files:**
- Modify: `Sources/mmReaderUI/ReaderView.swift`
- Modify: `Sources/mmReaderUI/ReaderWindowController.swift`
- Test: `Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests.

`Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift`
```swift
@MainActor
@Test func readerViewAppliesHexTextColor() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    view.applyTextColorHex("#33AAFF")

    #expect(view.debugTextColorHexForTesting == "#33AAFF")
}
```

`Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift`
```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
swift test --filter 'readerViewAppliesHexTextColor|applyingTextColorPersistsToConfig'
```
Expected: FAIL because color application APIs do not exist.

- [ ] **Step 3: Write minimal implementation**

In `Sources/mmReaderUI/ReaderView.swift`, add:

```swift
private var currentTextColorHex = "#000000"

public func applyTextColorHex(_ hex: String) {
    currentTextColorHex = hex
    renderText()
}

public var debugTextColorHexForTesting: String { currentTextColorHex }
```

Apply the resolved color in `renderText()`:

```swift
.foregroundColor: color(from: currentTextColorHex).withAlphaComponent(currentTextAlpha)
```

Add a small local converter in `ReaderView`.

In `Sources/mmReaderUI/ReaderWindowController.swift`, wire the new control callback:

```swift
contentView.controlsView.onTextColorHexChanged = { [weak self] hex in
    guard let self else { return }
    self.controllerState.config.textColorHex = hex
    self.applyConfigToUI()
    self.persistConfigDebounced()
}
```

And apply the config value in `applyConfigToUI()`:

```swift
contentView.readerView.applyTextColorHex(controllerState.config.textColorHex)
```

Expose a test helper:

```swift
func debugSetTextColorHexForTesting(_ hex: String) {
    controllerState.config.textColorHex = hex
    applyConfigToUI()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
swift test --filter 'readerViewAppliesHexTextColor|applyingTextColorPersistsToConfig'
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderView.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift
 git commit -m "feat: apply and persist text color"
```

---

### Task 5: Keep HEX and RGB fields synchronized and reject invalid values

**Files:**
- Modify: `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Test: `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift`.

```swift
@MainActor
@Test func controlsPopoverHexUpdatesRgbFields() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))

    controls.debugSetTextColorHexForTesting("#33AAFF")

    #expect(controls.debugTextColorRgbForTesting() == (51, 170, 255))
}

@MainActor
@Test func controlsPopoverRgbUpdatesHexField() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))

    controls.debugSetTextColorRGBForTesting(r: 17, g: 34, b: 51)

    #expect(controls.debugTextColorHexForTesting == "#112233")
}

@MainActor
@Test func controlsPopoverRejectsInvalidHexInput() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 360, height: 420))
    var received: String?
    controls.onTextColorHexChanged = { received = $0 }

    controls.debugSetTextColorHexForTesting("#XYZ")

    #expect(received == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
swift test --filter 'controlsPopoverHexUpdatesRgbFields|controlsPopoverRgbUpdatesHexField|controlsPopoverRejectsInvalidHexInput'
```
Expected: FAIL because synchronization and validation are incomplete.

- [ ] **Step 3: Write minimal implementation**

In `Sources/mmReaderUI/ReaderControlsPopoverView.swift`, add normalization helpers:

```swift
private func normalizedHex(_ raw: String) -> String? { ... }
private func rgb(from hex: String) -> (Int, Int, Int)? { ... }
private func hex(r: Int, g: Int, b: Int) -> String { ... }
```

On valid HEX input:
- normalize to `#RRGGBB`
- update RGB fields
- emit one callback

On valid RGB input:
- clamp 0...255
- update HEX field
- emit one callback

Expose test helpers:

```swift
var debugTextColorHexForTesting: String { textColorHexField.stringValue }
func debugTextColorRgbForTesting() -> (Int, Int, Int) { ... }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
swift test --filter 'controlsPopoverHexUpdatesRgbFields|controlsPopoverRgbUpdatesHexField|controlsPopoverRejectsInvalidHexInput'
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderUI/ReaderControlsPopoverView.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift
git commit -m "feat: synchronize hex and rgb text color fields"
```

---

### Task 6: Run full verification

**Files:**
- Modify: any files still needed from prior tasks
- Test: full suite and app build

- [ ] **Step 1: Run targeted tests for open path and color controls**

Run:
```bash
swift test --filter 'saveThenLoadPreservesTextColor|controlsPopoverHexChangeEmitsNormalizedColor|controlsPopoverRgbChangeEmitsNormalizedColor|readerViewAppliesHexTextColor|controlsPopoverHexUpdatesRgbFields|openingFileUsesConfiguredLinesPerPageWithoutExtraRepaginateCalls'
```
Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:
```bash
swift test
```
Expected: PASS.

- [ ] **Step 3: Build distributable app bundle**

Run:
```bash
bash scripts/build_app.sh
```
Expected: PASS and emit `build/mmReader.app`.

- [ ] **Step 4: Build DMG package**

Run:
```bash
bash scripts/build_dmg.sh
```
Expected: PASS and emit `build/mmReader.dmg`.

- [ ] **Step 5: Commit**

```bash
git add Sources/mmReaderCore/ReaderConfig.swift Sources/mmReaderCore/ReaderEngine.swift Sources/mmReaderUI/ReaderDocumentSession.swift Sources/mmReaderUI/ReaderSessionInteractor.swift Sources/mmReaderUI/ReaderControlsPopoverView.swift Sources/mmReaderUI/ReaderView.swift Sources/mmReaderUI/ReaderWindowController.swift Tests/mmReaderCoreTests/ConfigStoreTests.swift Tests/mmReaderCoreTests/ReaderEngineTests.swift Tests/mmReaderCoreTests/ReaderWindowControllerTests.swift Tests/mmReaderCoreTests/ReaderWindowContentViewTests.swift Tests/mmReaderCoreTests/ReaderViewInteractionTests.swift Tests/mmReaderCoreTests/SessionPagingTests.swift
git commit -m "feat: add text color controls and speed up file open"
```
