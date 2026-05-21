import AppKit
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func windowFactoryCreatesBorderlessWindowWithConfiguredGeometry() {
    var cfg = ReaderConfig.default
    cfg.windowX = 210
    cfg.windowY = 220
    cfg.windowWidth = 730
    cfg.windowHeight = 910

    let window = ReaderWindowFactory.makeWindow(config: cfg)

    #expect(window.frame.origin.x == 210)
    #expect(window.frame.origin.y == 220)
    #expect(window.frame.size.width == 730)
    #expect(window.frame.size.height == 910)
}

@MainActor
@Test func windowFactoryDoesNotImposeMinimumSize() {
    let window = ReaderWindowFactory.makeWindow(config: .default)

    #expect(window.minSize == .zero)
    #expect(window.contentMinSize == .zero)
}

@MainActor
@Test func windowFactoryCreatesResizableInteractiveWindow() {
    let window = ReaderWindowFactory.makeWindow(config: .default)

    #expect(window.styleMask.contains(.titled))
    #expect(window.styleMask.contains(.resizable))
    #expect(window.styleMask.contains(.fullSizeContentView))
}
