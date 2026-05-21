public struct ToolbarVisibilityState {
    public private(set) var isVisible: Bool

    public init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    public mutating func toggle() {
        isVisible.toggle()
    }
}
