import AppKit

@MainActor
public enum WindowAppearanceConfigurator {
    public static func apply(to window: NSWindow, isPinned: Bool) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.level = isPinned ? .floating : .normal
    }

    public static func applyBackgroundAlpha(_ alpha: Double, to window: NSWindow) {
        window.backgroundColor = NSColor.clear.withAlphaComponent(alpha)
    }
}
