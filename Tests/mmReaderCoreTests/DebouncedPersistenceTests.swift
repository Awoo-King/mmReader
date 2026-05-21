import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@MainActor
@Test func persistConfigNowWritesImmediately() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var cfg = ReaderConfig.default
    cfg.windowX = 333
    cfg.windowY = 444

    let wc = ReaderWindowController(configStore: store)
    wc.replaceConfigForTesting(cfg)
    wc.persistConfigNow()

    let loaded = store.load()
    #expect(loaded.windowX == 333)
    #expect(loaded.windowY == 444)
}

@MainActor
@Test func persistConfigDebouncedCoalescesRapidRequests() async throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var saveCount = 0

    let wc = ReaderWindowController(
        configStore: store,
        saveObserver: { _ in
            saveCount += 1
        }
    )

    var cfg = ReaderConfig.default
    cfg.windowWidth = 777
    wc.replaceConfigForTesting(cfg)

    wc.persistConfigDebounced()
    wc.persistConfigDebounced()
    wc.persistConfigDebounced()

    try await Task.sleep(for: .milliseconds(1800))

    #expect(saveCount == 1)
    let loaded = store.load()
    #expect(loaded.windowWidth == 777)
}
