import AppKit

@MainActor
public enum WindowInstaller {
    public static func install(contentView: ReaderWindowContentView, into window: NSWindow, isPinned: Bool) {
        window.contentView = contentView
        WindowAppearanceConfigurator.apply(to: window, isPinned: isPinned)
    }
}
