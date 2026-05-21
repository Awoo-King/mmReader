import Testing
@testable import mmReaderUI

@Test func toolbarProgressFormatsZeroTotalAsDefault() {
    #expect(ToolbarProgressFormatter.format(page: 1, total: 0) == "0/0 0%")
}

@Test func toolbarProgressFormatsPercentFromPageAndTotal() {
    #expect(ToolbarProgressFormatter.format(page: 3, total: 10) == "3/10 30%")
}
