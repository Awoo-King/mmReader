import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@Test func lifecycleCoordinatorRestoreUpdatesState() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let file = tempRoot.appendingPathComponent("restore.txt")
    try (0..<120).map { "line \($0)" }.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.lastFilePath = file.path
    cfg.lastAnchor = 220
    store.save(cfg)

    var interactor = ReaderSessionInteractor(configStore: store)
    var state = ReaderControllerState(config: cfg)

    let coordinator = ReaderWindowLifecycleCoordinator()
    coordinator.restore(into: &state, via: &interactor)

    #expect(state.currentDocumentPath == file.path)
    #expect(state.currentAnchor == 220)
}

@Test func lifecycleCoordinatorHandleDropReturnsHandledFlag() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let good = tempRoot.appendingPathComponent("good.md")
    try "hello".write(to: good, atomically: true, encoding: .utf8)

    let store = ConfigStore(baseURL: tempRoot)
    var interactor = ReaderSessionInteractor(configStore: store)
    var state = ReaderControllerState(config: .default)

    let coordinator = ReaderWindowLifecycleCoordinator()
    let handled = coordinator.handleDrop(good, state: &state, interactor: &interactor)

    #expect(handled == true)
    #expect(state.currentDocumentPath == good.path)
}
