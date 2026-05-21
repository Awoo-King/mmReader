import AppKit

@MainActor
public struct ToolbarVisibilityController {
    public private(set) var state: ToolbarVisibilityState
    private weak var toolbarView: ToolbarView?

    public var isVisible: Bool { state.isVisible }

    public init(toolbarView: ToolbarView, state: ToolbarVisibilityState = ToolbarVisibilityState()) {
        self.toolbarView = toolbarView
        self.state = state
        toolbarView.isHidden = !state.isVisible
    }

    public mutating func toggle() {
        state.toggle()
        toolbarView?.isHidden = !state.isVisible
    }

    public mutating func setVisible(_ visible: Bool) {
        if visible == state.isVisible { return }
        toggle()
    }
}
