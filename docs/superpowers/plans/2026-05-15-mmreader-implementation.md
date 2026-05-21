# mmReader P0/P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a stable macOS transparent text reader (P0) with correct pagination/state recovery, then package it as a double-clickable app bundle (P1).

**Architecture:** Use Swift + AppKit with clear units: app lifecycle (`AppDelegate`), window behavior (`ReaderWindowController`), rendering (`ReaderView`), controls (`ToolbarView`), document/pagination state (`ReaderEngine`), and persistence (`ConfigStore`). Implement P0 first with deterministic startup and atomic file switching, then add packaging + release validation in P1.

**Tech Stack:** Swift 5.x, AppKit, Xcodebuild, XCTest (unit + integration-style component tests)

---

## Scope check

This spec is already split into dependent layers (P0 correctness → P1 packaging). A single plan is appropriate because P1 depends on P0 behavior guarantees.

## Planned file structure (target)

- Create: `mmReader/mmReader.xcodeproj` (project scaffold)
- Create: `mmReader/mmReader/AppDelegate.swift` — app lifecycle, menu, in-app shortcuts
- Create: `mmReader/mmReader/ReaderWindowController.swift` — borderless window + toolbar visibility + geometry events
- Create: `mmReader/mmReader/ReaderView.swift` — pure text rendering only
- Create: `mmReader/mmReader/ToolbarView.swift` — page/percent display + controls
- Create: `mmReader/mmReader/ReaderEngine.swift` — load/normalize/paginate/anchor mapping
- Create: `mmReader/mmReader/ConfigStore.swift` — config read/write/fallback + debounce-safe persistence API
- Create: `mmReader/mmReader/Models.swift` — `ReaderConfig`, `DocumentState`, `PageAnchor`
- Create: `mmReader/mmReaderTests/ReaderEngineTests.swift`
- Create: `mmReader/mmReaderTests/ConfigStoreTests.swift`
- Create: `mmReader/mmReaderTests/StartupRecoveryTests.swift`
- Create: `mmReader/mmReaderTests/FileSwitchAtomicityTests.swift`
- Create: `scripts/build_app.sh` — reproducible app build for P1

---

### Task 1: Scaffold macOS AppKit project and app entrypoint

**Files:**
- Create: `mmReader/mmReader.xcodeproj`
- Create: `mmReader/mmReader/AppDelegate.swift`
- Test: `xcodebuild` build check

- [ ] **Step 1: Create failing build check (project missing)**

Run: `xcodebuild -project mmReader/mmReader.xcodeproj -scheme mmReader -configuration Debug build`
Expected: FAIL with “project does not exist”.

- [ ] **Step 2: Create project + app target (AppKit lifecycle)**

Required entry content in `AppDelegate.swift`:
```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: ReaderWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = ReaderWindowController()
        windowController.showWindow(self)
    }
}
```

- [ ] **Step 3: Build to verify scaffold compiles**

Run: `xcodebuild -project mmReader/mmReader.xcodeproj -scheme mmReader -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit scaffold**

```bash
git add mmReader/mmReader.xcodeproj mmReader/mmReader/AppDelegate.swift
git commit -m "chore: scaffold appkit project and app entrypoint"
```

---

### Task 2: Define core models and config defaults (TDD)

**Files:**
- Create: `mmReader/mmReader/Models.swift`
- Create: `mmReader/mmReader/ConfigStore.swift`
- Test: `mmReader/mmReaderTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing tests for config decode/default fallback**

```swift
func testDecodeInvalidConfigFallsBackToDefaults() throws {
    let store = ConfigStore(baseURL: tempURL)
    try "{ invalid json".write(to: store.configURL, atomically: true, encoding: .utf8)

    let cfg = store.load()

    XCTAssertEqual(cfg.fontSize, 18)
    XCTAssertEqual(cfg.linesPerPage, 30)
    XCTAssertEqual(cfg.lastPageIndex, 0)
    XCTAssertNil(cfg.lastFilePath)
}

func testRoundTripPersistsLastAnchor() throws {
    let store = ConfigStore(baseURL: tempURL)
    var cfg = ReaderConfig.default
    cfg.lastAnchor = 1200
    store.save(cfg)

    let loaded = store.load()
    XCTAssertEqual(loaded.lastAnchor, 1200)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/ConfigStoreTests`
Expected: FAIL (types not defined).

- [ ] **Step 3: Implement minimal models + store**

`Models.swift` minimum:
```swift
struct ReaderConfig: Codable {
    var fontSize: Double
    var bgAlpha: Double
    var textAlpha: Double
    var linesPerPage: Int
    var windowX: Double
    var windowY: Double
    var windowWidth: Double
    var windowHeight: Double
    var isPinned: Bool
    var isFullscreen: Bool
    var lastFilePath: String?
    var lastPageIndex: Int
    var lastAnchor: Int?

    static let `default` = ReaderConfig(
        fontSize: 18, bgAlpha: 0.85, textAlpha: 1.0, linesPerPage: 30,
        windowX: 120, windowY: 120, windowWidth: 680, windowHeight: 840,
        isPinned: false, isFullscreen: false, lastFilePath: nil,
        lastPageIndex: 0, lastAnchor: nil
    )
}
```

`ConfigStore.swift` minimum:
```swift
final class ConfigStore {
    let configURL: URL
    init(baseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mmreader")) { ... }
    func load() -> ReaderConfig { ... } // fallback + rewrite on decode failure
    func save(_ config: ReaderConfig) { ... }
}
```

- [ ] **Step 4: Re-run tests to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/Models.swift mmReader/mmReader/ConfigStore.swift mmReader/mmReaderTests/ConfigStoreTests.swift
git commit -m "feat: add config model and resilient config store"
```

---

### Task 3: Implement ReaderEngine load/paginate/anchor mapping (TDD)

**Files:**
- Create: `mmReader/mmReader/ReaderEngine.swift`
- Test: `mmReader/mmReaderTests/ReaderEngineTests.swift`

- [ ] **Step 1: Write failing tests for format support + anchor-based remap**

```swift
func testSupportsTxtAndMdOnly() {
    XCTAssertTrue(ReaderEngine.supports(url: URL(fileURLWithPath: "/a.txt")))
    XCTAssertTrue(ReaderEngine.supports(url: URL(fileURLWithPath: "/a.md")))
    XCTAssertFalse(ReaderEngine.supports(url: URL(fileURLWithPath: "/a.pdf")))
}

func testRepaginateKeepsSemanticPositionByAnchor() throws {
    var engine = ReaderEngine()
    try engine.load(text: longText)
    engine.goToPage(5)
    let beforeAnchor = engine.currentAnchor

    engine.repaginate(linesPerPage: 20)

    XCTAssertEqual(engine.currentAnchor, beforeAnchor, accuracy: 120)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/ReaderEngineTests`
Expected: FAIL (engine missing).

- [ ] **Step 3: Implement minimal ReaderEngine**

Required API:
```swift
struct ReaderEngine {
    static func supports(url: URL) -> Bool
    mutating func load(url: URL) throws
    mutating func load(text: String) throws
    mutating func repaginate(linesPerPage: Int)
    mutating func goToPage(_ index: Int)

    var pages: [String] { get }
    var currentPageIndex: Int { get }
    var currentAnchor: Int { get }
}
```

Implementation requirement: maintain `pageIndex` + `anchor`, and remap page from anchor on repagination.

- [ ] **Step 4: Re-run tests to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/ReaderEngine.swift mmReader/mmReaderTests/ReaderEngineTests.swift
git commit -m "feat: implement text reader engine with anchor-based repagination"
```

---

### Task 4: Build borderless window + pure text reader view (TDD)

**Files:**
- Create: `mmReader/mmReader/ReaderWindowController.swift`
- Create: `mmReader/mmReader/ReaderView.swift`
- Test: `mmReader/mmReaderTests/StartupRecoveryTests.swift` (window style checks)

- [ ] **Step 1: Write failing test for borderless style and no progress UI in reader**

```swift
func testWindowIsBorderless() {
    let wc = ReaderWindowController()
    _ = wc.window
    XCTAssertTrue(wc.window?.styleMask.contains(.borderless) == true)
}

func testReaderViewDoesNotExposeProgressLabels() {
    let view = ReaderView(frame: .init(x: 0, y: 0, width: 400, height: 300))
    XCTAssertNil(view.subviews.first { $0 is NSTextField })
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/StartupRecoveryTests`
Expected: FAIL.

- [ ] **Step 3: Implement minimal window + reader view**

`ReaderWindowController` requirements:
- use `.borderless`
- host `ReaderView` as main content
- no progress/percent in main view

`ReaderView` requirements:
- `NSTextView` or custom draw-only text content
- fixed line spacing 4pt
- minimal content insets

- [ ] **Step 4: Re-run tests to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/ReaderWindowController.swift mmReader/mmReader/ReaderView.swift mmReader/mmReaderTests/StartupRecoveryTests.swift
git commit -m "feat: add borderless reader window and pure text reading view"
```

---

### Task 5: Add toolbar UI + Cmd+B toggle + active-app shortcut scope (TDD)

**Files:**
- Create: `mmReader/mmReader/ToolbarView.swift`
- Modify: `mmReader/mmReader/AppDelegate.swift`
- Modify: `mmReader/mmReader/ReaderWindowController.swift`
- Test: `mmReader/mmReaderTests/StartupRecoveryTests.swift`

- [ ] **Step 1: Write failing tests for toolbar visibility toggling**

```swift
func testCommandBTogglesToolbarVisibility() {
    let wc = ReaderWindowController()
    let initial = wc.isToolbarVisible
    wc.toggleToolbar()
    XCTAssertNotEqual(wc.isToolbarVisible, initial)
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/StartupRecoveryTests/testCommandBTogglesToolbarVisibility`
Expected: FAIL.

- [ ] **Step 3: Implement minimal toolbar integration**

Requirements:
- `ToolbarView` shows `current/total` + `%`
- `ReaderWindowController.toggleToolbar()` toggles visibility
- Register `⌘B` in app menu/action path (app active only, no global hook)

- [ ] **Step 4: Re-run test to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/ToolbarView.swift mmReader/mmReader/AppDelegate.swift mmReader/mmReader/ReaderWindowController.swift mmReader/mmReaderTests/StartupRecoveryTests.swift
git commit -m "feat: add toolbar and app-scoped command-b toggle"
```

---

### Task 6: Implement startup restore ordering and atomic file switching (TDD)

**Files:**
- Modify: `mmReader/mmReader/AppDelegate.swift`
- Modify: `mmReader/mmReader/ReaderWindowController.swift`
- Modify: `mmReader/mmReader/ReaderEngine.swift`
- Create: `mmReader/mmReaderTests/FileSwitchAtomicityTests.swift`
- Modify: `mmReader/mmReaderTests/StartupRecoveryTests.swift`

- [ ] **Step 1: Write failing startup/order + atomicity tests**

```swift
func testStartupRestoresWindowThenDocumentThenPage() throws {
    // set config with geometry + last file + page/anchor
    // launch controller through app delegate hook
    // assert geometry applied and restored page matches expected section
}

func testFailedOpenKeepsCurrentDocumentAndPage() throws {
    // open valid file A
    // attempt invalid file B
    // assert current page content still belongs to A
}
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/StartupRecoveryTests -only-testing:mmReaderTests/FileSwitchAtomicityTests`
Expected: FAIL.

- [ ] **Step 3: Implement deterministic restore + two-phase file load**

Implementation requirements:
- startup order exactly per spec
- loading new file happens in temp state, commit only on full success
- failures preserve prior in-memory state

- [ ] **Step 4: Re-run tests to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/AppDelegate.swift mmReader/mmReader/ReaderWindowController.swift mmReader/mmReader/ReaderEngine.swift mmReader/mmReaderTests/StartupRecoveryTests.swift mmReader/mmReaderTests/FileSwitchAtomicityTests.swift
git commit -m "feat: restore startup state deterministically and switch files atomically"
```

---

### Task 7: Add debounced persistence for geometry/display state (TDD)

**Files:**
- Modify: `mmReader/mmReader/ConfigStore.swift`
- Modify: `mmReader/mmReader/ReaderWindowController.swift`
- Modify: `mmReader/mmReaderTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing tests for debounced write behavior**

```swift
func testRapidGeometryUpdatesDebounceToSingleWrite() throws {
    let store = SpyConfigStore(...)
    let wc = ReaderWindowController(configStore: store)

    wc.simulateGeometryChange()
    wc.simulateGeometryChange()
    wc.simulateGeometryChange()

    wait(for: 0.4)
    XCTAssertEqual(store.saveCallCount, 1)
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS' -only-testing:mmReaderTests/ConfigStoreTests/testRapidGeometryUpdatesDebounceToSingleWrite`
Expected: FAIL.

- [ ] **Step 3: Implement debounced persist entrypoint**

Required API in window controller:
```swift
func persistConfigDebounced()
func persistConfigNow()
```
Debounce window: 150–300ms (choose one constant and keep it in code as a single source).

- [ ] **Step 4: Re-run test to pass**

Run command from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mmReader/mmReader/ConfigStore.swift mmReader/mmReader/ReaderWindowController.swift mmReader/mmReaderTests/ConfigStoreTests.swift
git commit -m "feat: debounce config persistence for high-frequency window events"
```

---

### Task 8: Verify P0 acceptance matrix end-to-end

**Files:**
- Modify: `mmReader/mmReaderTests/StartupRecoveryTests.swift`
- Modify: `mmReader/mmReaderTests/ReaderEngineTests.swift`
- Modify: `mmReader/mmReaderTests/FileSwitchAtomicityTests.swift`

- [ ] **Step 1: Add any missing acceptance assertions from spec matrix**

Add explicit test coverage for:
- bad config fallback
- unsupported format handling
- repagination continuity
- app-active-only shortcuts

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS'`
Expected: all tests PASS.

- [ ] **Step 3: Manual P0 smoke run in app**

Run app in Xcode and verify:
- txt/md open + drag-drop
- toolbar toggles with cmd+b
- restart restores state
- failed open does not blank prior document

- [ ] **Step 4: Commit P0 verification updates**

```bash
git add mmReader/mmReaderTests/StartupRecoveryTests.swift mmReader/mmReaderTests/ReaderEngineTests.swift mmReader/mmReaderTests/FileSwitchAtomicityTests.swift
git commit -m "test: complete p0 acceptance coverage and smoke verification"
```

---

### Task 9: Implement reproducible P1 build script and app packaging checks

**Files:**
- Create: `scripts/build_app.sh`
- Modify: `mmReader/mmReader.xcodeproj` (archive/export config as needed)

- [ ] **Step 1: Write failing packaging check**

Run: `bash scripts/build_app.sh`
Expected: FAIL (script missing).

- [ ] **Step 2: Implement minimal build script**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build"
APP_NAME="mmReader.app"

xcodebuild -project "$ROOT_DIR/mmReader/mmReader.xcodeproj" \
  -scheme mmReader -configuration Release build \
  -derivedDataPath "$OUT_DIR/DerivedData"

APP_PATH="$(find "$OUT_DIR/DerivedData" -name "$APP_NAME" | head -n 1)"
[ -d "$APP_PATH" ]
cp -R "$APP_PATH" "$OUT_DIR/$APP_NAME"

echo "Built: $OUT_DIR/$APP_NAME"
```

- [ ] **Step 3: Run script to verify app bundle generated**

Run: `bash scripts/build_app.sh`
Expected: prints `Built: .../build/mmReader.app`.

- [ ] **Step 4: Commit P1 build script**

```bash
git add scripts/build_app.sh mmReader/mmReader.xcodeproj
git commit -m "build: add reproducible app bundle packaging script"
```

---

### Task 10: Validate P1 double-click launch and behavior parity

**Files:**
- Modify: `mmReader/mmReaderTests/StartupRecoveryTests.swift` (if launch assertions can be automated)
- Create: `docs/superpowers/specs/p1-release-checklist.txt` (optional local checklist artifact)

- [ ] **Step 1: Run packaging script and launch app bundle manually**

Run: `open build/mmReader.app`
Expected: app launches from Finder-open path without Xcode.

- [ ] **Step 2: Execute parity checklist**

Verify packaged app matches P0 for:
- open txt/md + drag-drop
- toolbar cmd+b
- restart recovery
- unsupported format error handling

- [ ] **Step 3: Capture final verification command outputs**

Run:
- `xcodebuild test -project mmReader/mmReader.xcodeproj -scheme mmReader -destination 'platform=macOS'`
- `bash scripts/build_app.sh`
Expected: both succeed.

- [ ] **Step 4: Commit P1 validation updates**

```bash
git add mmReader/mmReaderTests/StartupRecoveryTests.swift docs/superpowers/specs/p1-release-checklist.txt
git commit -m "test: validate packaged app launch and p0 behavior parity"
```

---

## Spec coverage self-review

- P0 borderless + pure reading area: Tasks 4, 5
- Toolbar-only progress + Cmd+B: Task 5
- TXT/MD + drag drop: Tasks 3, 8
- Active-app-only shortcuts: Tasks 5, 8
- Config persistence + recovery + corrupted fallback: Tasks 2, 6, 7, 8
- Repagination semantic continuity: Tasks 3, 8
- Failed open keeps current content: Task 6
- P1 packaging to `.app`: Tasks 9, 10

No uncovered spec requirement remains.

## Placeholder/type consistency self-review

- No TODO/TBD placeholders in implementation steps.
- Core types referenced consistently: `ReaderConfig`, `ReaderEngine`, `ReaderWindowController`, `ConfigStore`, `lastAnchor`.
- Command set is explicit for each test/build checkpoint.

---

Plan complete and saved to `docs/superpowers/plans/2026-05-15-mmreader-implementation.md`. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?