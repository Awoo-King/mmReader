# mmReader startup/open/text-color design

Date: 2026-05-19

## Goal

Fix the current file-open performance path and add text color customization without disturbing the controls, window persistence, shortcut, shell, or pin work that already landed.

Specifically:
- Make startup restore and File > Open stop feeling stalled
- Ensure opening a new TXT/MD file reliably replaces current content
- Add text color configuration with both HEX and RGB inputs
- Apply text color changes immediately and persist them across launches

## Scope

This round includes:
1. Startup and File > Open performance cleanup
2. Reliable open-file replacement behavior
3. Text color controls with HEX and RGB
4. Persistent text color restore on next launch

This round does not include:
- Background color customization
- System color picker integration
- Shell/status-item behavior changes
- Pin behavior changes
- New pagination semantics beyond making the current visual-line path efficient and correct

## User-approved behavior

### Startup and open-file behavior
- Startup should no longer visibly stall as long during restore
- File > Open should always replace the current document and refresh content immediately
- The fix should remove redundant pagination/layout passes rather than masking the delay

### Text color customization
- Controls should expose text color only
- User can edit color by HEX and RGB
- Changes should apply immediately
- HEX and RGB stay in sync both directions
- Invalid input should not replace the last valid color
- Color should persist across relaunch

### Language consistency
- Controls should stay Chinese-only
- Avoid mixing Chinese and English in the same user-facing settings surface

## Architecture

### Performance and open-file flow

The current visual-line paging path does too much work when restoring or opening a file. The expensive operation is visual pagination in `ReaderEngine`, which now uses AppKit text layout. That work is valid, but the surrounding flow calls it more than once during a single file-open path.

The fix is to make file load and pagination parameter application explicit and single-pass:
- update pagination parameters once
- load document once
- paginate once
- emit one snapshot to the UI

This keeps the visual-line paging model but removes repeated full-document layout in the same operation.

### Text color model

Add a single persisted text color value in config, with HEX as the canonical serialized representation and RGB derived for editing.

Why HEX as source of truth:
- compact to persist
- easy to validate and compare
- easy to derive RGB from

Controls will still show both:
- one HEX field
- three RGB fields

Reader rendering consumes the resolved text color directly. No extra color abstraction is needed.

## File-level plan

### `Sources/mmReaderCore/ReaderConfig.swift`
- Add persisted text color field
- Use one canonical string form, e.g. `#RRGGBB`
- Default stays a normal readable system-like dark text color

### `Sources/mmReaderCore/ReaderEngine.swift`
- Keep visual-line pagination
- Reduce duplicate relayout work in single file-load flows
- Keep configuration updates explicit (`linesPerPage`, width, font size)

### `Sources/mmReaderUI/ReaderDocumentSession.swift`
- Central place to fix repeated file-open pagination calls
- Open and restore should update pagination inputs once and page once
- Add text color persistence handoff via config only, not via engine

### `Sources/mmReaderUI/ReaderSessionInteractor.swift`
- Continue to expose snapshots after open/pagination updates
- Add/update color-related snapshot flow only if needed by controller

### `Sources/mmReaderUI/ReaderControlsPopoverView.swift`
- Add text color editing controls
- Keep surface Chinese-only
- Wire HEX + RGB immediate change callbacks

### `Sources/mmReaderUI/ReaderView.swift`
- Apply resolved text color directly to displayed text
- Preserve regular system font, no shadow, transparent background

### `Sources/mmReaderUI/ReaderWindowController.swift`
- Wire controls callbacks into config/session updates
- Ensure open-file and restore refresh UI immediately after single-pass paging
- Apply persisted text color on launch and after control changes

## Data flow

### File open / restore
1. Controller asks session/interactor to open or restore
2. Session updates pagination inputs once from current config
3. Session loads text once
4. Engine computes visual-line pages once
5. Session returns one snapshot
6. Controller applies snapshot and refreshes view

### Text color change from HEX
1. User edits HEX field
2. Controls validate input
3. Controls emit normalized color value
4. Controller updates config and view immediately
5. Controls refresh RGB fields from normalized value
6. Config persists debounced

### Text color change from RGB
1. User edits one RGB field
2. Controls validate/clamp input
3. Controls build normalized HEX value
4. Controller updates config and view immediately
5. Controls refresh HEX field from normalized value
6. Config persists debounced

## Error handling rules

- Invalid HEX should not apply a new color
- Invalid RGB should not apply a new color
- Last valid value remains displayed/applied until a valid replacement is provided
- File-open failure should still leave current document untouched
- No extra recovery UI is needed in this round

## Tests required

### Performance/open path
- A single open path should not invoke duplicate pagination passes for the same input set
- Opening a new file should replace displayed text immediately
- Restoring a saved file should still restore content correctly after the flow cleanup

### Text color config
- Config saves and loads the text color field
- Default config includes expected default text color value

### Controls
- HEX input emits normalized color
- RGB input emits normalized color
- HEX updates RGB display
- RGB updates HEX display
- Invalid values do not emit changes

### Reader rendering
- Reader view applies persisted text color
- Reader view still uses regular system font
- Reader view still has no shadow

## Acceptance criteria

- Startup restore no longer feels obviously stuck on repeated work
- File > Open reliably loads a new TXT/MD file
- Text color can be changed by HEX and RGB
- Changes apply immediately
- Color persists across relaunch
- Existing controls, shortcuts, shell modes, pin state, and window memory still work
