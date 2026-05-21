# mmReader shell/status/close/shortcut design

Date: 2026-05-17

## Goal

Productize the remaining shell-level behavior in mmReader without a broad refactor. This round finishes the current UI/config/event skeleton by wiring it through to real macOS behavior.

Specifically:
- Make Pin a leftmost toolbar icon button with real pinned/unpinned visual state
- Make the status item real and clickable
- Make shell mode truly switch Dock and status-bar presence
- Intercept window close and route it through app shell rules
- Make shortcut settings drive menu shortcuts and runtime actions immediately

## Current context

The repo already has the right persistence and event skeleton:
- `ReaderConfig` persists `isPinned`, `isToolbarVisible`, `shellMode`, `closeBehavior`, and `shortcuts`
- `ReaderControlsPopoverView` emits shell mode, close behavior, and shortcut change events
- `ReaderWindowController` receives those events and persists config
- `StatusItemController` exists but is still a menu skeleton
- `AppDelegate` applies an initial shell mode and builds a static main menu

The design should preserve this shape and complete the behavior rather than introducing a new architecture layer.

## Chosen approach

Use a thin extension of the existing app shell structure.

Why this approach:
- Fastest path to shipping the missing behavior
- Keeps current boundaries intact
- Avoids a speculative coordinator refactor before product behavior is complete

Rejected alternatives:
1. Introduce a new `AppShellCoordinator` first. Better long-term isolation, but too much refactor for this round.
2. Ship only the visible UI pieces now and defer runtime shortcut rebinding. Faster, but incomplete relative to the requested scope.

## Scope

This round includes five capability groups:
1. Pin iconization and toolbar reordering
2. Real status item creation and click behavior
3. True shell mode switching
4. Real close interception and routing
5. Runtime shortcut rebinding, including a modest expansion of supported actions

This round does not include:
- Global system-wide shortcuts
- Shortcut conflict-detection UI
- Deep status-item menu design
- Terminology cleanup for shell mode / close behavior labels
- Large architecture refactors

## User-approved behavior

### Shell mode

#### `dockOnly`
- Dock is visible
- Status item is hidden
- Closing the main window keeps the app alive in the Dock
- The user can return by clicking the Dock icon

#### `statusItemOnly`
- Dock is hidden (`.accessory` activation policy)
- Status item is visible
- Left-clicking the status item toggles the main window
- Closing the main window leaves the app resident in the status bar

#### `dockAndStatusItem`
- Dock is visible
- Status item is visible
- Left-clicking the status item toggles the main window
- Closing the main window leaves the app resident in the status bar

### Close behavior

There are two persisted close-behavior values:
- `hideWindow`
- `quitApp`

But actual window-close handling is shell-aware.

Effective rule:
- `dockOnly` close keeps the app alive in the Dock
- `statusItemOnly` close keeps the app alive in the status bar
- `dockAndStatusItem` close keeps the app alive in the status bar
- Explicit quit still exits the app

Implementation note:
- The real close button / Close action should be intercepted and routed through shell rules first
- `closeBehavior` continues to control whether an explicit close-style action hides or quits when that distinction matters
- Status-item primary interaction is not a Close action; primary interaction is window toggle

### Status item interaction

Primary interaction:
- Left-click toggles the reader window

Secondary interaction:
- Menu remains available as an auxiliary control surface
- The menu should not replace the primary left-click toggle interaction

### Shortcuts

This round supports runtime-configurable shortcuts for:
- Previous page
- Next page
- Toggle toolbar
- Open file
- Close window
- Toggle main window
- Toggle controls
- Toggle pin
- Hide toolbar

Runtime rules:
- Updating a shortcut immediately updates the corresponding menu item key equivalent
- Updating a shortcut immediately updates runtime behavior without restart
- Each action has exactly one active binding
- No conflict-detection UI in this round
- If two actions are assigned the same binding, last write wins in the action-routing layer

## Structural design

### `ToolbarView`

Responsibilities:
- Render top toolbar controls
- Emit user actions through closures
- Reflect current pinned state visually

Changes:
- Move Pin to the leftmost position
- Replace the text button with an icon button
- Keep the existing `onTogglePin` callback
- Preserve current Open / Controls / Close / Hide actions

Testing focus:
- Pin button is leftmost
- Pin icon changes when `isPinned` changes

### `StatusItemController`

Responsibilities:
- Own the real `NSStatusItem`
- Expose shell-level status item behavior through a narrow API
- Keep menu assembly and click wiring local to the status item

Changes:
- Upgrade from menu skeleton to real `NSStatusItem`
- Add API to show/hide the status item
- Add API to reflect pinned state and window-visibility state
- Wire menu items to real target/actions or callbacks
- Support primary left-click window toggle behavior

Testing focus:
- Visibility toggles correctly
- Left-click trigger reaches the toggle-window callback
- Menu actions invoke expected callbacks
- Visible state can be inspected in tests

### `AppDelegate`

Responsibilities:
- Remain the app-shell composition root
- Build and own the main menu
- Connect window controller, menu actions, shell mode, and status item

Changes:
- Keep the current role instead of introducing a new coordinator
- Wire status item callbacks to window actions
- Apply shell mode changes at launch and when config changes at runtime
- Update activation policy when shell mode changes
- Rebind menu-item shortcuts when shortcut config changes
- Handle Dock-icon reopen behavior when the app stays alive without a visible window

Testing focus:
- Activation policy matches shell mode
- Status item visibility matches shell mode
- Menu items receive updated key equivalents when shortcuts change
- Reopen path can show the window again when appropriate

### `ReaderWindowController`

Responsibilities:
- Own window-level behavior and config-driven UI updates
- Stay as the place where control-surface changes become config writes

Changes:
- Add explicit show/hide/toggle window operations
- Add a close-request handling path rather than relying only on raw `close()`
- Notify app-level shell integration when shell mode, close behavior, or shortcuts change
- Continue persisting config after updates

Testing focus:
- Close requests route correctly based on shell mode and close behavior
- Pin changes update config and window appearance
- Control updates continue persisting config
- Shell and shortcut changes produce app-visible updates

### `ShortcutSettingsView`

Responsibilities:
- Present editable bindings for supported actions
- Reflect current binding values in the UI
- Emit binding changes

Changes:
- Expand the action list to cover the approved actions
- Show current key/modifier values beside each action
- Continue emitting `onShortcutChanged`

Testing focus:
- Expanded action list is correct
- Current values render correctly
- Change events emit correct bindings

## Data and control flow

### Shell mode update
1. User changes shell mode in controls
2. `ReaderControlsPopoverView` emits `onShellModeChanged`
3. `ReaderWindowController` updates `ReaderConfig.shellMode` and persists it
4. App-level callback notifies `AppDelegate`
5. `AppDelegate` updates activation policy and status-item visibility
6. Window behavior follows the new shell rules immediately

### Close request
1. User clicks the window close button or triggers the close action
2. `ReaderWindowController` intercepts the close request
3. Shell mode is checked first
4. Effective action is derived:
   - stay resident in Dock
   - stay resident in status bar
   - quit app
5. Window visibility updates accordingly
6. Status-item state refreshes if present

### Shortcut update
1. User changes a shortcut in settings
2. `ShortcutSettingsView` emits the new binding
3. `ReaderWindowController` updates `ReaderConfig.shortcuts` and persists it
4. App-level callback notifies `AppDelegate`
5. `AppDelegate` updates menu-item key equivalents and action routing
6. New shortcut works immediately without restart

## Error handling and edge rules

- If a status item is hidden by shell mode, status-item callbacks should become inert rather than crash
- If the window does not yet exist during an app-shell callback, the action should no-op safely
- Shortcut duplication is allowed in this round; later writes override earlier routing
- `dockOnly` must not strand the user with no visible entry point after close; the Dock remains the recovery path
- `statusItemOnly` must not require the Dock to recover the window; the status item remains the recovery path

## Testing plan

Automated tests should cover:

### `StatusItemController`
- Visibility toggling
- Left-click toggle callback path
- Menu-action callback wiring
- Pinned / visible state representation if surfaced for tests

### `AppDelegate`
- Shell mode to activation policy mapping
- Shell mode to status-item visibility mapping
- Runtime shortcut rebinding of menu items
- App reopen behavior when no window is visible

### `ReaderWindowController`
- Close routing across shell modes and close behaviors
- Config writes for pin / shell / close / shortcut updates
- App-level notification hooks for shell and shortcut changes

### `ToolbarView`
- Pin button ordering
- Pin icon state changes

### `ShortcutSettingsView`
- Expanded action list
- Current-value rendering
- Binding emission

Manual verification after build:
- Launch built app
- Switch among all three shell modes
- Close and reopen window from Dock or status item as applicable
- Verify left-click status-item toggle
- Verify Pin icon state changes
- Verify at least a few updated shortcuts without restart

## Implementation notes

Keep the design incremental.

Preferred file set for this round:
- `Sources/mmReaderUI/ToolbarView.swift`
- `Sources/mmReaderUI/StatusItemController.swift`
- `Sources/mmReaderUI/AppDelegate.swift`
- `Sources/mmReaderUI/ReaderWindowController.swift`
- `Sources/mmReaderUI/ShortcutSettingsView.swift`
- supporting model files only if shortcut action vocabulary must expand

Do not introduce a new app-shell coordinator unless implementation reveals a hard blocker.
