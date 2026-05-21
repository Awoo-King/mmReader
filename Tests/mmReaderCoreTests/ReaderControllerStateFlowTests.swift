import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func controllerStateApplyCanBeUsedForRestoreAndDropFlows() {
    var state = ReaderControllerState(config: .default)

    var cfgRestore = ReaderConfig.default
    cfgRestore.windowX = 101
    let restoreSnapshot = ReaderSessionSnapshot(
        documentPath: "/tmp/restore.txt",
        anchor: 7,
        config: cfgRestore,
        pageIndex: 1,
        totalPages: 4,
        pageText: "restore"
    )
    state.apply(snapshot: restoreSnapshot)

    #expect(state.currentDocumentPath == "/tmp/restore.txt")
    #expect(state.currentAnchor == 7)
    #expect(state.currentPageIndex == 1)
    #expect(state.totalPages == 4)
    #expect(state.currentPageText == "restore")
    #expect(state.config.windowX == 101)

    var cfgDrop = ReaderConfig.default
    cfgDrop.windowY = 202
    let dropSnapshot = ReaderSessionSnapshot(
        documentPath: "/tmp/drop.txt",
        anchor: 11,
        config: cfgDrop,
        pageIndex: 2,
        totalPages: 5,
        pageText: "drop"
    )
    state.apply(snapshot: dropSnapshot)

    #expect(state.currentDocumentPath == "/tmp/drop.txt")
    #expect(state.currentAnchor == 11)
    #expect(state.currentPageIndex == 2)
    #expect(state.totalPages == 5)
    #expect(state.currentPageText == "drop")
    #expect(state.config.windowY == 202)
}
