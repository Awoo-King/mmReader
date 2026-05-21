import AppKit
import Foundation
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func windowContentViewContainsReaderAndToolbar() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))

    #expect(content.subviews.count == 2)
    #expect(content.toolbarView.superview === content)
    #expect(content.readerView.superview === content)
    #expect(content.debugHasInlineControlsForTesting == false)
}

@MainActor
@Test func windowContentViewRegistersForFileURLDrops() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))

    #expect(content.registeredDraggedTypes.contains(.fileURL))
}

@MainActor
@Test func handleDroppedFileURLUsesInstalledHandlerResult() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))
    let url = URL(fileURLWithPath: "/tmp/book.md")
    var receivedURL: URL?
    content.fileDropHandler = {
        receivedURL = $0
        return true
    }

    let handled = content.handleDroppedFileURL(url)

    #expect(handled == true)
    #expect(receivedURL == url)
}

@MainActor
@Test func controlsPopoverContentIsVisibleWhenDetached() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))

    #expect(content.controlsView.isHidden == false)
}

@MainActor
@Test func controlsPopoverDetachedFromWindowContentView() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))

    #expect(content.debugHasInlineControlsForTesting == false)
    #expect(content.controlsView.superview == nil)
}

@MainActor
@Test func controlsPopoverUsesFloatingPanelInsteadOfParticipatingInMainLayout() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))

    #expect(content.debugHasInlineControlsForTesting == false)
}

@MainActor
@Test func controlsPopoverUsesChineseOnlyLabels() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 320, height: 320))

    #expect(controls.debugSectionLabelsForTesting() == ["字号", "行数", "文字", "背景", "模式", "关闭"])
}

@MainActor
@Test func controlsPopoverGivesShortcutEditorUsableWidth() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 320, height: 320))
    controls.layoutSubtreeIfNeeded()

    #expect(controls.debugShortcutScrollWidthForTesting >= 180)
}

@MainActor
@Test func controlsPopoverDoesNotForceOverlyCompactOverallHeight() {
    let content = ReaderWindowContentView(frame: NSRect(x: 0, y: 0, width: 680, height: 840))
    content.layoutSubtreeIfNeeded()

    #expect(content.controlsView.frame.height >= 280)
}

@MainActor
@Test func controlsPopoverPlacesShortcutEditorInsideScrollView() {
    let controls = ReaderControlsPopoverView(frame: .init(x: 0, y: 0, width: 320, height: 320))
    controls.layoutSubtreeIfNeeded()

    #expect(controls.shortcutSettingsView.enclosingScrollView != nil)
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

@MainActor
@Test func shortcutSettingsEditEmitsBindingChange() {
    let shortcuts = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))
    var capturedAction: String?
    var capturedBinding: ReaderShortcutBindings.Key?
    shortcuts.onShortcutChanged = { action, binding in
        capturedAction = action
        capturedBinding = binding
    }

    let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [.command, .shift],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "M",
        charactersIgnoringModifiers: "m",
        isARepeat: false,
        keyCode: 0
    )!
    shortcuts.debugPerformKeyEventForTesting(action: "显隐主窗口", event: event)

    #expect(capturedAction == "显隐主窗口")
    #expect(capturedBinding == .init(key: "m", modifiers: ["command", "shift"]))
}

@MainActor
@Test func shortcutSettingsCapturesLeftArrowAsStableKey() {
    let shortcuts = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))
    var capturedBinding: ReaderShortcutBindings.Key?
    shortcuts.onShortcutChanged = { _, binding in
        capturedBinding = binding
    }

    let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)),
        charactersIgnoringModifiers: String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)),
        isARepeat: false,
        keyCode: 123
    )!
    shortcuts.debugPerformKeyEventForTesting(action: "上一页", event: event)

    #expect(capturedBinding == .init(key: "leftArrow", modifiers: []))
}

@MainActor
@Test func shortcutSettingsCapturesRightArrowAsStableKey() {
    let shortcuts = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))
    var capturedBinding: ReaderShortcutBindings.Key?
    shortcuts.onShortcutChanged = { _, binding in
        capturedBinding = binding
    }

    let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)),
        charactersIgnoringModifiers: String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)),
        isARepeat: false,
        keyCode: 124
    )!
    shortcuts.debugPerformKeyEventForTesting(action: "下一页", event: event)

    #expect(capturedBinding == .init(key: "rightArrow", modifiers: []))
}

@MainActor
@Test func shortcutSettingsDisplaysStableHumanReadableKeyNames() {
    let shortcuts = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))

    shortcuts.apply(shortcuts: ReaderShortcutBindings(
        previousPage: .init(key: "leftArrow"),
        nextPage: .init(key: "rightArrow"),
        toggleToolbar: .init(key: "b", modifiers: ["command"]),
        openFile: .init(key: "slash", modifiers: ["command", "shift"]),
        closeWindow: .init(key: "space", modifiers: []),
        toggleMainWindow: .init(key: "m", modifiers: ["command"]),
        toggleControls: .init(key: "comma", modifiers: ["command"]),
        togglePin: .init(key: "period", modifiers: ["option"]),
        hideToolbar: .init(key: "tab", modifiers: ["command"])
    ))

    #expect(shortcuts.debugDisplayedBindingForTesting(action: "上一页") == "←")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "下一页") == "→")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "打开文件") == "⇧⌘/")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "关闭窗口") == "Space")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "显隐 Controls") == "⌘,")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "切换置顶") == "⌥.")
    #expect(shortcuts.debugDisplayedBindingForTesting(action: "隐藏工具栏") == "⌘Tab")
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
        textColorHex: "#000000",
        shortcuts: shortcuts
    )

    #expect(controls.shortcutSettingsView.debugDisplayedBindingForTesting(action: "显隐主窗口") == "⌘M")
    #expect(controls.shortcutSettingsView.debugDisplayedBindingForTesting(action: "隐藏工具栏") == "⇧⌘H")
}

@MainActor
@Test func toolbarExposesCloseAction() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))
    var closeCount = 0

    toolbar.onCloseWindow = { closeCount += 1 }
    toolbar.debugTriggerCloseWindowForTesting()

    #expect(closeCount == 1)
}
