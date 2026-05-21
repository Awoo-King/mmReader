import AppKit

@MainActor
public final class StatusItemController: NSObject {
    private let menu = NSMenu()
    private var statusItem: NSStatusItem?
    private(set) var isVisible = true
    public var onToggleWindow: (() -> Void)?
    public var onShowWindow: (() -> Void)?
    public var onHideWindow: (() -> Void)?
    public var onTogglePin: (() -> Void)?
    public var onOpenFile: (() -> Void)?
    public var onQuit: (() -> Void)?

    public override init() {
        super.init()
        buildMenu()
        configureStatusItemButton()
        setVisible(true)
    }

    var debugIsVisibleForTesting: Bool { isVisible }
    var debugHasStatusItemForTesting: Bool { statusItem != nil }
    var debugHasAttachedMenuForTesting: Bool { statusItem?.menu != nil }

    func debugMenuForTesting() -> NSMenu {
        menu
    }

    func setVisible(_ visible: Bool) {
        if visible {
            isVisible = true
            installStatusItem()
        } else {
            isVisible = false
            removeStatusItem()
        }
    }

    func debugTriggerToggleWindowForTesting() { onToggleWindow?() }
    func debugTriggerShowWindowForTesting() { onShowWindow?() }
    func debugTriggerHideWindowForTesting() { onHideWindow?() }
    func debugTriggerTogglePinForTesting() { onTogglePin?() }
    func debugTriggerOpenFileForTesting() { onOpenFile?() }
    func debugTriggerQuitForTesting() { onQuit?() }
    func debugPerformPrimaryClickForTesting() { primaryClicked() }
    func debugShowMenuForTesting() {
        statusItem?.button?.performClick(nil)
    }

    private func configureStatusItemButton() {
        statusItem?.button?.image = NSImage(systemSymbolName: "book", accessibilityDescription: "mmReader")
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(primaryClicked)
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem?.menu = nil
    }

    @objc
    private func primaryClicked() {
        guard let event = NSApp.currentEvent else {
            onToggleWindow?()
            return
        }
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            guard let button = statusItem?.button else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            return
        }
        onToggleWindow?()
    }

    @objc
    private func showWindowClicked() {
        onShowWindow?()
    }

    @objc
    private func hideWindowClicked() {
        onHideWindow?()
    }

    @objc
    private func togglePinClicked() {
        onTogglePin?()
    }

    @objc
    private func openFileClicked() {
        onOpenFile?()
    }

    @objc
    private func quitClicked() {
        onQuit?()
    }

    private func buildMenu() {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "显示窗口", action: #selector(showWindowClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "隐藏窗口", action: #selector(hideWindowClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "置顶", action: #selector(togglePinClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开文件", action: #selector(openFileClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitClicked), keyEquivalent: ""))
        menu.items.forEach { item in
            item.target = item.isSeparatorItem ? nil : self
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemButton()
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }
}
