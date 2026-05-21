import AppKit
import Testing
@testable import mmReaderUI

@MainActor
@Test func toolbarCanBeMadeFullyTransparent() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 300, height: 30))
    toolbar.setTransparentMode(true)
    #expect(toolbar.debugBackgroundAlphaForTesting == 0)
}

@MainActor
@Test func pinButtonUsesImageStateInsteadOfText() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))

    toolbar.setPinned(false)
    #expect(toolbar.debugPinTitleForTesting == "置顶")
    #expect(toolbar.debugPinHasImageForTesting == true)

    toolbar.setPinned(true)
    #expect(toolbar.debugPinTitleForTesting == "已置顶")
    #expect(toolbar.debugPinHasAlternateImageForTesting == true)
}

@MainActor
@Test func pinButtonUsesDistinctVisualStateWhenPinned() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 600, height: 30))

    toolbar.setPinned(false)
    #expect(toolbar.debugPinUsesFilledSymbolForTesting == false)
    #expect(toolbar.debugPinHasEmphasisTintForTesting == false)
    #expect(toolbar.debugPinTitleForTesting == "置顶")

    toolbar.setPinned(true)
    #expect(toolbar.debugPinUsesFilledSymbolForTesting == true)
    #expect(toolbar.debugPinHasEmphasisTintForTesting == true)
    #expect(toolbar.debugPinTitleForTesting == "已置顶")
}
