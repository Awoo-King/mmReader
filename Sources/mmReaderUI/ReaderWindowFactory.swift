import AppKit
import mmReaderCore

@MainActor
final class ReaderWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
public enum ReaderWindowFactory {
    public static func makeWindow(config: ReaderConfig) -> NSWindow {
        ReaderWindow(
            contentRect: NSRect(
                x: config.windowX,
                y: config.windowY,
                width: config.windowWidth,
                height: config.windowHeight
            ),
            styleMask: [.titled, .resizable, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
    }
}
