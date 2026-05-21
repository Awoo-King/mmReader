import AppKit
import UniformTypeIdentifiers
import mmReaderCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var windowController: ReaderWindowController?
    private let statusItemController = StatusItemController()

    static let openDocumentContentTypes: [UTType] = [
        .plainText,
        UTType(filenameExtension: "md") ?? .plainText
    ]

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = ReaderWindowController()
        self.windowController = controller
        statusItemController.onToggleWindow = { [weak self] in
            self?.windowController?.toggleWindowVisibility()
        }
        statusItemController.onShowWindow = { [weak self] in
            self?.windowController?.showWindowAndActivate()
        }
        statusItemController.onHideWindow = { [weak self] in
            self?.windowController?.hideWindow()
        }
        statusItemController.onTogglePin = { [weak self] in
            self?.windowController?.togglePinForApp()
        }
        statusItemController.onOpenFile = { [weak self] in
            self?.openDocument(nil)
        }
        statusItemController.onQuit = {
            NSApp.terminate(nil)
        }
        controller.onShellModeChangedForApp = { [weak self] mode in
            self?.apply(shellMode: mode)
        }
        controller.onShortcutsChangedForApp = { [weak self] shortcuts in
            guard let self, var config = self.windowController?.debugConfigForTesting else { return }
            config.shortcuts = shortcuts
            NSApp.mainMenu = self.buildMainMenu(config: config)
        }
        controller.onQuitRequestedForApp = {
            NSApp.terminate(nil)
        }
        controller.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        controller.window?.makeKeyAndOrderFront(self)
        apply(shellMode: controller.debugConfigForTesting.shellMode)
        NSApp.mainMenu = buildMainMenu(config: controller.debugConfigForTesting)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        windowController?.showWindowAndActivate()
        return true
    }

    @objc
    private func openDocument(_ sender: Any?) {
        guard let windowController else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.openDocumentContentTypes

        if panel.runModal() == .OK, let url = panel.url {
            _ = windowController.handleDroppedFile(url)
        }
    }

    func debugOpenDocumentFile(_ url: URL) {
        _ = windowController?.handleDroppedFile(url)
    }

    @objc
    private func nextPage(_ sender: Any?) {
        _ = windowController?.moveToNextPage()
    }

    @objc
    private func previousPage(_ sender: Any?) {
        _ = windowController?.moveToPreviousPage()
    }

    @objc
    private func toggleToolbar(_ sender: Any?) {
        windowController?.toggleToolbar()
    }

    @objc
    private func toggleMainWindow(_ sender: Any?) {
        windowController?.toggleWindowVisibility()
    }

    @objc
    private func toggleControls(_ sender: Any?) {
        windowController?.toggleControlsVisibilityForApp()
    }

    @objc
    private func togglePin(_ sender: Any?) {
        windowController?.togglePinForApp()
    }

    @objc
    private func hideToolbar(_ sender: Any?) {
        windowController?.hideToolbarForApp()
    }

    @objc
    private func closeWindow(_ sender: Any?) {
        _ = windowController?.handleCloseRequest()
    }

    func debugBuildMainMenu() -> NSMenu {
        buildMainMenu(config: windowController?.debugConfigForTesting ?? .default)
    }

    func debugBuildMainMenu(config: ReaderConfig) -> NSMenu {
        buildMainMenu(config: config)
    }

    func debugApplyShellMode(_ shellMode: ReaderShellMode) {
        apply(shellMode: shellMode)
    }

    var debugStatusItemVisibleForTesting: Bool {
        statusItemController.debugIsVisibleForTesting
    }

    var debugStatusItemInstalledForTesting: Bool {
        statusItemController.debugHasStatusItemForTesting
    }

    func debugActivationPolicy(for shellMode: ReaderShellMode) -> NSApplication.ActivationPolicy {
        activationPolicy(for: shellMode)
    }

    func debugShouldQuitOnClose(_ behavior: ReaderCloseBehavior) -> Bool {
        shouldQuitOnClose(behavior)
    }

    private func apply(shellMode: ReaderShellMode) {
        NSApp.setActivationPolicy(activationPolicy(for: shellMode))
        switch shellMode {
        case .dockOnly:
            statusItemController.setVisible(false)
        case .statusItemOnly, .dockAndStatusItem:
            statusItemController.setVisible(true)
        }
    }

    private func activationPolicy(for shellMode: ReaderShellMode) -> NSApplication.ActivationPolicy {
        switch shellMode {
        case .dockOnly, .dockAndStatusItem:
            return .regular
        case .statusItemOnly:
            return .accessory
        }
    }

    private func shouldQuitOnClose(_ behavior: ReaderCloseBehavior) -> Bool {
        behavior == .quitApp
    }

    private func menuKeyEquivalent(from binding: ReaderShortcutBindings.Key) -> String {
        switch binding.key {
        case "upArrow": return String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        case "downArrow": return String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        case "leftArrow": return String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
        case "rightArrow": return String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        default: return binding.key
        }
    }

    private func modifierFlags(from modifiers: [String]) -> NSEvent.ModifierFlags {
        modifiers.reduce(into: NSEvent.ModifierFlags()) { flags, modifier in
            switch modifier {
            case "command": flags.insert(.command)
            case "shift": flags.insert(.shift)
            case "option": flags.insert(.option)
            case "control": flags.insert(.control)
            default: break
            }
        }
    }

    private func buildMainMenu(config: ReaderConfig) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit mmReader", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.openFile))
        openItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.openFile.modifiers)
        openItem.target = self
        fileMenu.addItem(openItem)

        let navMenuItem = NSMenuItem()
        mainMenu.addItem(navMenuItem)
        let navMenu = NSMenu(title: "Navigate")
        navMenuItem.submenu = navMenu

        let toggleToolbarItem = NSMenuItem(title: "Toggle Toolbar", action: #selector(toggleToolbar(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.toggleToolbar))
        toggleToolbarItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.toggleToolbar.modifiers)
        toggleToolbarItem.target = self
        navMenu.addItem(toggleToolbarItem)

        let toggleWindowItem = NSMenuItem(title: "Toggle Window", action: #selector(toggleMainWindow(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.toggleMainWindow))
        toggleWindowItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.toggleMainWindow.modifiers)
        toggleWindowItem.target = self
        navMenu.addItem(toggleWindowItem)

        let toggleControlsItem = NSMenuItem(title: "Toggle Controls", action: #selector(toggleControls(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.toggleControls))
        toggleControlsItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.toggleControls.modifiers)
        toggleControlsItem.target = self
        navMenu.addItem(toggleControlsItem)

        let togglePinItem = NSMenuItem(title: "Toggle Pin", action: #selector(togglePin(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.togglePin))
        togglePinItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.togglePin.modifiers)
        togglePinItem.target = self
        navMenu.addItem(togglePinItem)

        let hideToolbarItem = NSMenuItem(title: "Hide Toolbar", action: #selector(hideToolbar(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.hideToolbar))
        hideToolbarItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.hideToolbar.modifiers)
        hideToolbarItem.target = self
        navMenu.addItem(hideToolbarItem)

        let closeWindowItem = NSMenuItem(title: "Close Window", action: #selector(closeWindow(_:)), keyEquivalent: menuKeyEquivalent(from: config.shortcuts.closeWindow))
        closeWindowItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.closeWindow.modifiers)
        closeWindowItem.target = self
        navMenu.addItem(closeWindowItem)

        let nextItem = NSMenuItem(
            title: "Next Page",
            action: #selector(nextPage(_:)),
            keyEquivalent: menuKeyEquivalent(from: config.shortcuts.nextPage)
        )
        nextItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.nextPage.modifiers)
        nextItem.target = self
        navMenu.addItem(nextItem)

        let prevItem = NSMenuItem(
            title: "Previous Page",
            action: #selector(previousPage(_:)),
            keyEquivalent: menuKeyEquivalent(from: config.shortcuts.previousPage)
        )
        prevItem.keyEquivalentModifierMask = modifierFlags(from: config.shortcuts.previousPage.modifiers)
        prevItem.target = self
        navMenu.addItem(prevItem)

        return mainMenu
    }
}
