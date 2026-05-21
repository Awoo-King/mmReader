import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func controllerStateAppliesSnapshotAndConfig() {
    var state = ReaderControllerState(config: .default)

    var cfg = ReaderConfig.default
    cfg.windowWidth = 888
    let snapshot = ReaderSessionSnapshot(
        documentPath: "/tmp/a.txt",
        anchor: 42,
        config: cfg,
        pageIndex: 2,
        totalPages: 10,
        pageText: "page 3"
    )

    state.apply(snapshot: snapshot)

    #expect(state.currentDocumentPath == "/tmp/a.txt")
    #expect(state.currentAnchor == 42)
    #expect(state.currentPageIndex == 2)
    #expect(state.totalPages == 10)
    #expect(state.currentPageText == "page 3")
    #expect(state.config.windowWidth == 888)
}
