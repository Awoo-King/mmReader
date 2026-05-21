# mmReader Controls + Window Behavior Design

## Context
mmReader already has core reading flow, paging, persistence, packaging, and basic shortcuts. Current gaps are now concentrated in two areas:

1. **Reading controls are incomplete.** The toolbar currently shows only reading progress. The user needs controls for font size, lines per page, text darkness, background transparency, pin-to-top, opening local files, and hiding the toolbar.
2. **Current window foundation is fighting the product goals.** The app still exhibits click-through / drag / resize problems. Earlier fixes improved keyboard focus, but the remaining behavior suggests the current fully borderless window approach is the wrong base for a transparent but interactive desktop reader.

The intended outcome is a reader that keeps a clean transparent aesthetic while behaving like a normal desktop app: clickable, draggable, resizable, persistent, and tunable at runtime.

## Goals
- Keep the reading surface visually minimal.
- Add runtime controls for:
  - font size
  - lines per page
  - text darkness
  - background transparency
  - pin-to-top
  - open local document
  - hide/show toolbar
- Persist all of those settings across launches.
- Add configurable runtime shell behavior:
  - `仅 Dock`
  - `仅状态栏`
  - `两者都显示`
- Add configurable close-window behavior:
  - hide window
  - quit app
- Add status bar presence with both click-toggle and menu actions.
- Add a simple shortcut settings surface for core actions.
- Eliminate click-through to windows behind mmReader.
- Make the window reliably draggable and resizable.
- Preserve current shortcuts, with paging moved to `↑` / `↓` and toolbar restore kept on `⌘B`.

## Non-goals
- Rich text styling or theme system beyond the controls above.
- Multi-window document management.
- In-app file browser or recent-files system.
- Full preferences window.
- Fully user-programmable shortcut system for every action in the app on this pass.

## User experience
### Toolbar shape
Use a **small top toolbar plus a popover control panel**.

The visible toolbar stays narrow and focused. It shows:
- Open button
- Controls button
- Pin button (`置顶` / `取消置顶` depending on current state)
- Hide toolbar button
- Existing reading progress label

The Controls button opens a popover anchored to the toolbar. That popover contains the adjustable reading controls.

### Popover controls
The popover contains four persistent controls:
- Font size slider / stepper
- Lines per page slider / stepper
- Text darkness slider
- Background transparency slider

Changes apply immediately to the current reader and persist automatically.

### Toolbar hiding
When the toolbar is hidden, it is restored **only** through `⌘B`. No hover hotspot is kept at the top edge.

### Paging keys
Paging uses keyboard arrows:
- `↑` previous page
- `↓` next page

### Runtime shell mode
User can choose one of three presentation modes:
- `仅 Dock`
- `仅状态栏`
- `两者都显示`

### Close-window behavior
User can choose one of two close behaviors:
- hide window
- quit app

### Status bar behavior
Status bar support must provide both:
- click on status item toggles main window show/hide
- status item menu exposes at least: show window, hide window, pin/unpin, open file, quit

### Shortcut settings
Provide a simple shortcut settings surface for core actions only:
- previous page
- next page
- toggle toolbar
- open file
- close window

## Window behavior direction
### Replace fully borderless foundation
Move away from the current pure `.borderless` window foundation and use a standard interactive AppKit window style configured to *look* borderless instead:
- titled window
- resizable window
- transparent title area / hidden title text
- visually minimal chrome
- content still fills the reading surface

This is the key product decision in the spec.

### Why
The current fully borderless approach has already needed special handling for focus and drag behavior, and it still does not provide reliable click, drag, and resize behavior. That pattern is now a liability. A normal interactive window base gives AppKit-native hit testing, resize behavior, and input routing while still allowing a transparent reading aesthetic.

### Required behavior
- Clicking any visible part of mmReader activates mmReader, not content behind it.
- Dragging from the toolbar moves the window.
- Dragging from the reader content area also moves the window when not interacting with a control.
- Window edges/corners can be resized naturally.
- Popover controls remain interactive and do not trigger drag behavior accidentally.

## State and persistence
### Existing fields to reuse
Continue using these `ReaderConfig` fields:
- `fontSize`
- `bgAlpha`
- `textAlpha`
- `linesPerPage`
- `isPinned`

### New fields
Add persistent fields for:
- `isToolbarVisible`
- runtime shell mode (`仅 Dock` / `仅状态栏` / `两者都显示`)
- close-window behavior (`hide` / `quit`)
- simple shortcut bindings for core actions

### Persistence rule
Any change made through toolbar or popover writes through existing config persistence so the next launch restores the same values.

## Component boundaries
### ReaderWindowController
Remains orchestration center. It should:
- receive toolbar and popover actions
- update `ReaderConfig`
- apply view/window updates
- coordinate status-item actions
- coordinate close-window behavior
- trigger persistence

### ToolbarView
Expands from passive progress label to active toolbar surface. It should:
- render core buttons and progress label
- expose callbacks/events upward
- show pin button text as `置顶` or `取消置顶` based on current state
- stay visually compact
- avoid owning persistence logic

### Status item coordinator
A dedicated status-item layer should:
- create and own `NSStatusItem`
- toggle main window visibility on click
- build menu actions for show/hide, pin/unpin, open file, quit
- react to runtime shell mode changes without pushing policy into view code

### Shortcut settings surface
A focused settings UI should:
- expose only core shortcut actions for now
- read and write shortcut config in one place
- keep menu bindings and runtime handlers in sync

### Controls popover
A focused UI component dedicated to control widgets. It should:
- own font/lines/text/background controls UI
- emit value changes upward
- not directly read/write config storage itself

### ReaderView
Applies reading presentation state. It should respond to:
- font size changes
- text darkness changes
- lines-per-page-driven repagination updates

### Window appearance layer
Window configuration should apply:
- pin-to-top state
- background transparency behavior
- interactive resize/drag behavior
- non-click-through behavior

## Data flow
1. User clicks toolbar button or changes popover control.
2. Toolbar / popover emits event to `ReaderWindowController`.
3. Controller mutates `ReaderConfig`.
4. Controller applies updated state to:
   - reader presentation
   - toolbar visibility / button state
   - window level / appearance
   - runtime shell mode (Dock/status item)
   - close behavior routing
   - shortcut binding state
   - pagination when needed
5. Controller triggers persistence through existing config path.

## File targets
Expected implementation area:
- `Sources/mmReaderCore/ReaderConfig.swift`
- `Sources/mmReaderUI/ReaderWindowFactory.swift`
- `Sources/mmReaderUI/WindowAppearanceConfigurator.swift`
- `Sources/mmReaderUI/ReaderWindowController.swift`
- `Sources/mmReaderUI/ReaderWindowContentView.swift`
- `Sources/mmReaderUI/ReaderView.swift`
- `Sources/mmReaderUI/ToolbarView.swift`
- new popover/control view file(s) in `Sources/mmReaderUI/`
- new status-item coordination file(s) in `Sources/mmReaderUI/`
- new simple shortcut-settings file(s) in `Sources/mmReaderUI/`
- related tests under `Tests/mmReaderCoreTests/`

## Testing expectations
### Automated
- toolbar actions update state correctly
- control changes persist to `ReaderConfig`
- restored config rehydrates toolbar visibility and reading settings
- pin state updates window level correctly
- content view / toolbar interactions do not regress drag-drop support
- window factory produces interactive, resizable window configuration
- runtime shell mode updates Dock/status-item behavior correctly
- close-window mode routes to hide vs quit correctly
- shortcut settings update core keybindings consistently

### Manual
On built `build/mmReader.app` verify:
1. click does not pass through to background window/page
2. window drags from toolbar
3. window drags from reader area
4. window resizes from edges/corners
5. `⌘O` opens `.txt` / `.md`
6. `↑` and `↓` page correctly
7. `⌘B` hides and restores toolbar
8. Open / Controls / Pin / Hide buttons work, and Pin text changes between `置顶` / `取消置顶`
9. font size, lines per page, text darkness, background transparency update immediately
10. runtime shell mode correctly switches between `仅 Dock` / `仅状态栏` / `两者都显示`
11. close-window mode correctly hides window or quits app according to setting
12. status item click toggles window and status item menu actions all work
13. shortcut settings page can update core shortcuts
14. all settings persist after relaunch
