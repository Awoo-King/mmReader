import AppKit
import Foundation
import mmReaderCore

@MainActor
public final class ReaderWindowController: NSWindowController {
    public var isToolbarVisible: Bool { toolbarVisibilityController.isVisible }
    public var currentDocumentPathForTesting: String? { controllerState.currentDocumentPath }
    public var currentAnchorForTesting: Int { controllerState.currentAnchor }
    public var displayedTextForTesting: String { contentView.displayedTextForTesting }
    public var onShellModeChangedForApp: ((ReaderShellMode) -> Void)?
    public var onCloseBehaviorChangedForApp: ((ReaderCloseBehavior) -> Void)?
    public var onShortcutsChangedForApp: ((ReaderShortcutBindings) -> Void)?
    public var onQuitRequestedForApp: (() -> Void)?
    var debugConfigForTesting: ReaderConfig { controllerState.config }
    var debugPinTitleForTesting: String { contentView.toolbarView.debugPinTitleForTesting }

    private let contentView = ReaderWindowContentView(frame: .zero)
    private let controlsPopover = NSPopover()

    private var toolbarVisibilityController: ToolbarVisibilityController
    private var controllerState: ReaderControllerState
    private var sessionInteractor: ReaderSessionInteractor
    private var lifecycleCoordinator = ReaderWindowLifecycleCoordinator()
    private let persistenceCoordinator: WindowPersistenceCoordinator
    private let saveObserver: ((ReaderConfig) -> Void)?

    private let emptyHintText = "⌘O 打开 TXT/MD\n[ / ] 翻页\n⌘B 显隐工具栏"

    public convenience init() {
        self.init(configStore: ConfigStore())
    }

    public init(configStore: ConfigStore, saveObserver: ((ReaderConfig) -> Void)? = nil) {
        self.toolbarVisibilityController = ToolbarVisibilityController(
            toolbarView: contentView.toolbarView
        )
        let deps = ReaderWindowDependenciesFactory.make(
            configStore: configStore,
            saveObserver: saveObserver
        )
        self.controllerState = deps.controllerState
        self.sessionInteractor = deps.sessionInteractor
        self.persistenceCoordinator = deps.persistenceCoordinator
        self.saveObserver = saveObserver

        let window = ReaderWindowFactory.makeWindow(config: controllerState.config)
        super.init(window: window)
        setupControlsPopover()
        setupDropHandling()
        setupToolbarActions()
        setupControlActions()
        setupWindow()
        applyConfigToUI()
        restoreLastFileIfAvailable()
        refreshVisibleContent()
    }

    required init?(coder: NSCoder) {
        self.toolbarVisibilityController = ToolbarVisibilityController(
            toolbarView: contentView.toolbarView
        )
        let deps = ReaderWindowDependenciesFactory.make(
            configStore: ConfigStore(),
            saveObserver: nil
        )
        self.controllerState = deps.controllerState
        self.sessionInteractor = deps.sessionInteractor
        self.persistenceCoordinator = deps.persistenceCoordinator
        self.saveObserver = nil
        super.init(coder: coder)
        setupControlsPopover()
        setupDropHandling()
        setupToolbarActions()
        setupControlActions()
        setupWindow()
        applyConfigToUI()
        refreshVisibleContent()
    }

    public func toggleToolbar() {
        setToolbarVisible(!toolbarVisibilityController.isVisible)
    }

    public func persistConfigNow() {
        persistenceCoordinator.persistNow(controllerState.config)
    }

    public func persistConfigDebounced() {
        persistenceCoordinator.persistDebounced(controllerState.config)
    }

    public func replaceConfigForTesting(_ newConfig: ReaderConfig) {
        controllerState.config = newConfig
        applyConfigToUI()
    }

    public func moveToNextPage() -> Bool {
        let moved = lifecycleCoordinator.moveToNextPage(state: &controllerState, interactor: &sessionInteractor)
        if moved {
            refreshVisibleContent()
            persistConfigDebounced()
        }
        return moved
    }

    public func moveToPreviousPage() -> Bool {
        let moved = lifecycleCoordinator.moveToPreviousPage(state: &controllerState, interactor: &sessionInteractor)
        if moved {
            refreshVisibleContent()
            persistConfigDebounced()
        }
        return moved
    }

    public func showWindowAndActivate() {
        guard let window else { return }
        showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(self)
    }

    public func hideWindow() {
        window?.orderOut(self)
    }

    public func toggleWindowVisibility() {
        guard let window else { return }
        if window.isVisible {
            hideWindow()
        } else {
            showWindowAndActivate()
        }
    }

    @discardableResult
    public func handleCloseRequest() -> Bool {
        switch controllerState.config.shellMode {
        case .dockOnly, .statusItemOnly, .dockAndStatusItem:
            hideWindow()
            return false
        }
    }

    @discardableResult
    public func handleDroppedFile(_ url: URL) -> Bool {
        let handled = lifecycleCoordinator.handleDrop(
            url,
            state: &controllerState,
            interactor: &sessionInteractor
        )
        if handled {
            refreshVisibleContent()
            saveObserver?(controllerState.config)
        }
        return handled
    }

    func debugApplyFontSizeForTesting(_ value: Double) {
        controllerState.config.fontSize = value
        applyConfigToUI()
    }

    func debugApplyLinesPerPageForTesting(_ value: Int) {
        controllerState.config.linesPerPage = value
        applyConfigToUI()
    }

    func debugSetLinesPerPageFromControlsForTesting(_ value: Int) {
        controllerState.config.linesPerPage = value
        let snapshot = sessionInteractor.updateLinesPerPage(value)
        controllerState.apply(snapshot: snapshot)
        applyConfigToUI()
    }

    func debugRebuildSessionForTesting(linesPerPage: Int) {
        controllerState.config.linesPerPage = linesPerPage
        if let path = controllerState.currentDocumentPath {
            let url = URL(fileURLWithPath: path)
            _ = handleDroppedFile(url)
        }
    }

    func debugApplyTextAlphaForTesting(_ value: Double) {
        controllerState.config.textAlpha = value
        applyConfigToUI()
    }

    func debugApplyBackgroundAlphaForTesting(_ value: Double) {
        controllerState.config.bgAlpha = value
        applyConfigToUI()
    }

    func debugSetTextColorHexForTesting(_ hex: String) {
        controllerState.config.textColorHex = hex
        applyConfigToUI()
    }

    func debugApplyShellModeForTesting(_ mode: ReaderShellMode) {
        controllerState.config.shellMode = mode
        onShellModeChangedForApp?(mode)
        applyConfigToUI()
    }

    func debugApplyCloseBehaviorForTesting(_ behavior: ReaderCloseBehavior) {
        controllerState.config.closeBehavior = behavior
        onCloseBehaviorChangedForApp?(behavior)
        applyConfigToUI()
    }

    func debugApplyShortcutForTesting(action: String, key: String, modifiers: [String]) {
        let binding = ReaderShortcutBindings.Key(key: key, modifiers: modifiers)
        switch action {
        case "上一页": controllerState.config.shortcuts.previousPage = binding
        case "下一页": controllerState.config.shortcuts.nextPage = binding
        case "显隐工具栏": controllerState.config.shortcuts.toggleToolbar = binding
        case "打开文件": controllerState.config.shortcuts.openFile = binding
        case "关闭窗口": controllerState.config.shortcuts.closeWindow = binding
        case "显隐主窗口": controllerState.config.shortcuts.toggleMainWindow = binding
        case "显隐 Controls": controllerState.config.shortcuts.toggleControls = binding
        case "切换置顶": controllerState.config.shortcuts.togglePin = binding
        case "隐藏工具栏": controllerState.config.shortcuts.hideToolbar = binding
        default: break
        }
        onShortcutsChangedForApp?(controllerState.config.shortcuts)
        applyConfigToUI()
    }

    func hideWindowForTesting() {
        hideWindow()
    }

    func showWindowForTesting() {
        showWindowAndActivate()
    }

    func toggleWindowVisibilityForTesting() {
        toggleWindowVisibility()
    }

    func toggleControlsVisibilityForApp() {
        toggleControlsVisibility()
    }

    func togglePinForApp() {
        togglePinState()
    }

    func debugTogglePinForTesting() {
        togglePinState()
    }

    func hideToolbarForApp() {
        setToolbarVisible(false)
    }

    private func setupControlsPopover() {
        controlsPopover.behavior = .transient
        controlsPopover.animates = false
        controlsPopover.contentSize = NSSize(width: 360, height: 360)
        controlsPopover.contentViewController = NSViewController()
        controlsPopover.contentViewController?.view = contentView.controlsView
        contentView.controlsView.frame = NSRect(x: 0, y: 0, width: 360, height: 360)
    }

    func debugOpenDocumentFileForTesting(_ url: URL) {
        _ = handleDroppedFile(url)
    }

    func debugPerformConfiguredCloseActionForTesting() {
        performConfiguredCloseAction()
    }

    var debugControlsPopoverHasContentViewControllerForTesting: Bool {
        controlsPopover.contentViewController != nil
    }

    var debugControlsPopoverUsesDetachedControlsViewForTesting: Bool {
        controlsPopover.contentViewController?.view === contentView.controlsView
    }

    func debugHandleCloseRequestForTesting() -> Bool {
        handleCloseRequest()
    }

    func debugPersistWindowFrameForTesting(_ frame: NSRect) {
        persistenceCoordinator.persistWindowFrameNow(frame, basedOn: controllerState.config)
        controllerState.config.windowX = frame.origin.x
        controllerState.config.windowY = frame.origin.y
        controllerState.config.windowWidth = frame.size.width
        controllerState.config.windowHeight = frame.size.height
    }

    private func setupDropHandling() {
        contentView.fileDropHandler = { [weak self] url in
            self?.handleDroppedFile(url) ?? false
        }
    }

    private func setupToolbarActions() {
        contentView.toolbarView.onOpen = { [weak self] in
            self?.openDocumentPanel()
        }
        contentView.toolbarView.onShowControls = { [weak self] in
            self?.toggleControlsVisibility()
        }
        contentView.toolbarView.onTogglePin = { [weak self] in
            self?.togglePinState()
        }
        contentView.toolbarView.onCloseWindow = { [weak self] in
            _ = self?.handleCloseRequest()
        }
        contentView.toolbarView.onHideToolbar = { [weak self] in
            self?.setToolbarVisible(false)
        }
    }

    private func setupControlActions() {
        contentView.controlsView.onFontSizeChanged = { [weak self] value in
            guard let self else { return }
            self.controllerState.config.fontSize = value
            let snapshot = self.sessionInteractor.updatePagination(
                linesPerPage: nil,
                fontSize: value,
                windowWidth: self.controllerState.config.windowWidth
            )
            self.controllerState.apply(snapshot: snapshot)
            self.applyConfigToUI()
            self.persistConfigDebounced()
        }
        contentView.controlsView.onLinesPerPageChanged = { [weak self] value in
            guard let self else { return }
            self.controllerState.config.linesPerPage = value
            let snapshot = self.sessionInteractor.updatePagination(
                linesPerPage: value,
                fontSize: nil,
                windowWidth: self.controllerState.config.windowWidth
            )
            self.controllerState.apply(snapshot: snapshot)
            self.applyConfigToUI()
            self.persistConfigDebounced()
        }
        contentView.controlsView.onTextAlphaChanged = { [weak self] value in
            self?.controllerState.config.textAlpha = value
            self?.applyConfigToUI()
            self?.persistConfigDebounced()
        }
        contentView.controlsView.onTextColorHexChanged = { [weak self] hex in
            self?.controllerState.config.textColorHex = hex
            self?.applyConfigToUI()
            self?.persistConfigDebounced()
        }
        contentView.controlsView.onShellModeChanged = { [weak self] mode in
            self?.controllerState.config.shellMode = mode
            self?.onShellModeChangedForApp?(mode)
            self?.persistConfigDebounced()
        }
        contentView.controlsView.onCloseBehaviorChanged = { [weak self] behavior in
            self?.controllerState.config.closeBehavior = behavior
            self?.onCloseBehaviorChangedForApp?(behavior)
            self?.persistConfigDebounced()
        }
        contentView.controlsView.shortcutSettingsView.onShortcutChanged = { [weak self] action, binding in
            self?.debugApplyShortcutForTesting(action: action, key: binding.key, modifiers: binding.modifiers)
            self?.persistConfigDebounced()
        }
    }

    private func setToolbarVisible(_ visible: Bool) {
        toolbarVisibilityController.setVisible(visible)
        controllerState.config.isToolbarVisible = visible
        setTrafficLightsHidden(true)
        persistConfigDebounced()
    }

    private func setTrafficLightsHidden(_ hidden: Bool) {
        guard let window else { return }
        window.standardWindowButton(.closeButton)?.isHidden = hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = hidden
        window.standardWindowButton(.zoomButton)?.isHidden = hidden
    }

    private func toggleControlsVisibility() {
        if controlsPopover.isShown {
            controlsPopover.performClose(nil)
        } else {
            controlsPopover.show(relativeTo: contentView.toolbarView.bounds, of: contentView.toolbarView, preferredEdge: .maxY)
        }
    }

    private func performConfiguredCloseAction() {
        switch controllerState.config.closeBehavior {
        case .hideWindow:
            hideWindow()
        case .quitApp:
            onQuitRequestedForApp?()
        }
    }

    private func togglePinState() {
        controllerState.config.isPinned.toggle()
        contentView.toolbarView.setPinned(controllerState.config.isPinned)
        if let window {
            WindowAppearanceConfigurator.apply(to: window, isPinned: controllerState.config.isPinned)
        }
        persistConfigDebounced()
    }

    private func openDocumentPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = AppDelegate.openDocumentContentTypes
        if panel.runModal() == .OK, let url = panel.url {
            _ = handleDroppedFile(url)
        }
    }

    private func applyConfigToUI() {
        contentView.readerView.applyFontSize(controllerState.config.fontSize)
        contentView.readerView.applyTextAlpha(controllerState.config.textAlpha)
        contentView.readerView.applyTextColorHex(controllerState.config.textColorHex)
        contentView.setToolbarTransparent(controllerState.config.bgAlpha <= 0.05)
        contentView.toolbarView.setPinned(controllerState.config.isPinned)
        contentView.controlsView.apply(
            fontSize: controllerState.config.fontSize,
            linesPerPage: controllerState.config.linesPerPage,
            textAlpha: controllerState.config.textAlpha,
            backgroundAlpha: controllerState.config.bgAlpha,
            textColorHex: controllerState.config.textColorHex,
            shortcuts: controllerState.config.shortcuts
        )
        toolbarVisibilityController.setVisible(controllerState.config.isToolbarVisible)
        setTrafficLightsHidden(true)
        if let window {
            WindowAppearanceConfigurator.applyBackgroundAlpha(controllerState.config.bgAlpha, to: window)
            WindowAppearanceConfigurator.apply(to: window, isPinned: controllerState.config.isPinned)
        }
    }

    private func restoreLastFileIfAvailable() {
        lifecycleCoordinator.restore(into: &controllerState, via: &sessionInteractor)
    }

    private func refreshVisibleContent() {
        if controllerState.currentPageText.isEmpty {
            contentView.setText(emptyHintText)
        } else {
            contentView.setText(controllerState.currentPageText)
        }
        contentView.toolbarView.update(page: controllerState.currentPageIndex + 1, total: controllerState.totalPages)
    }

    private func setupWindow() {
        guard let window else { return }

        WindowInstaller.install(
            contentView: contentView,
            into: window,
            isPinned: controllerState.config.isPinned
        )
        window.delegate = self
        setTrafficLightsHidden(true)
    }
}

extension ReaderWindowController: NSWindowDelegate {
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        handleCloseRequest()
    }

    public func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        persistenceCoordinator.persistWindowFrameDebounced(window.frame, basedOn: controllerState.config)
    }

    public func windowDidResize(_ notification: Notification) {
        guard let window else { return }
        controllerState.config.windowWidth = window.frame.width
        controllerState.config.windowHeight = window.frame.height
        let snapshot = sessionInteractor.updatePagination(
            linesPerPage: nil,
            fontSize: nil,
            windowWidth: window.frame.width
        )
        controllerState.apply(snapshot: snapshot)
        refreshVisibleContent()
        persistenceCoordinator.persistWindowFrameDebounced(window.frame, basedOn: controllerState.config)
    }
}
