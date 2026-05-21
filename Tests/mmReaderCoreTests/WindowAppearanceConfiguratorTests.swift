import AppKit
import Testing
@testable import mmReaderUI

@MainActor
@Test func appearanceConfiguratorAppliesFloatingLevelWhenPinned() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
        styleMask: [.titled, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    WindowAppearanceConfigurator.apply(to: window, isPinned: true)

    #expect(window.isMovableByWindowBackground == true)
    #expect(window.backgroundColor == .clear)
    #expect(window.isOpaque == false)
    #expect(window.level == .floating)
}

@MainActor
@Test func appearanceConfiguratorAppliesNormalLevelWhenNotPinned() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
        styleMask: [.titled, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    WindowAppearanceConfigurator.apply(to: window, isPinned: false)

    #expect(window.level == .normal)
}

@MainActor
@Test func windowAppearanceDisablesMousePassThrough() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
        styleMask: [.titled, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    WindowAppearanceConfigurator.apply(to: window, isPinned: false)

    #expect(window.ignoresMouseEvents == false)
}

@MainActor
@Test func windowAppearanceAppliesBackgroundAlpha() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
        styleMask: [.titled, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    WindowAppearanceConfigurator.applyBackgroundAlpha(0.4, to: window)

    #expect(window.backgroundColor.alphaComponent == 0.4)
}
