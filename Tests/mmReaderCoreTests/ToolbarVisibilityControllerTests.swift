import AppKit
import Testing
@testable import mmReaderUI

@MainActor
@Test func visibilityControllerStartsVisibleAndReflectsToolbar() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 100, height: 30))
    let controller = ToolbarVisibilityController(toolbarView: toolbar)

    #expect(controller.isVisible == true)
    #expect(toolbar.isHidden == false)
}

@MainActor
@Test func visibilityControllerToggleUpdatesStateAndView() {
    let toolbar = ToolbarView(frame: .init(x: 0, y: 0, width: 100, height: 30))
    var controller = ToolbarVisibilityController(toolbarView: toolbar)

    controller.toggle()
    #expect(controller.isVisible == false)
    #expect(toolbar.isHidden == true)

    controller.toggle()
    #expect(controller.isVisible == true)
    #expect(toolbar.isHidden == false)
}
