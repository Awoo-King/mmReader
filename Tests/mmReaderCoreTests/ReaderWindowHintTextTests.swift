import Foundation
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@MainActor
@Test func controllerShowsHintTextWhenNoDocumentLoaded() {
    let store = ConfigStore(baseURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
    let wc = ReaderWindowController(configStore: store)

    #expect(wc.displayedTextForTesting.contains("⌘O"))
    #expect(wc.displayedTextForTesting.contains("TXT/MD"))
}
