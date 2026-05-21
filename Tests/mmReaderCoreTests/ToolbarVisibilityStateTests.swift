import Testing
@testable import mmReaderUI

@Test func toolbarVisibilityStateStartsVisible() {
    let state = ToolbarVisibilityState()
    #expect(state.isVisible == true)
}

@Test func toolbarVisibilityStateTogglesValue() {
    var state = ToolbarVisibilityState()
    state.toggle()
    #expect(state.isVisible == false)
    state.toggle()
    #expect(state.isVisible == true)
}
