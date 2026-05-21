import AppKit
import Testing
@testable import mmReaderUI

@MainActor
@Test func windowInstallerSetsContentViewAndAppliesAppearance() {
    let window = NSWindow(
        contentRect: .init(x: 0, y: 0, width: 300, height: 300),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let content = ReaderWindowContentView(frame: .init(x: 0, y: 0, width: 300, height: 300))

    WindowInstaller.install(contentView: content, into: window, isPinned: true)

    #expect(window.contentView === content)
    #expect(window.level == .floating)
}
