import Foundation
import Testing
@testable import mmReaderUI
@testable import mmReaderCore

@Test func lifecycleCoordinatorNextPageAdvancesWhenPossible() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("book.txt")
    let text = (0..<120).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: file, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var interactor = ReaderSessionInteractor(configStore: store)
    var state = ReaderControllerState(config: .default)
    let coordinator = ReaderWindowLifecycleCoordinator()

    _ = coordinator.handleDrop(file, state: &state, interactor: &interactor)
    let moved = coordinator.moveToNextPage(state: &state, interactor: &interactor)

    #expect(moved == true)
    #expect(state.currentAnchor > 0)
}
