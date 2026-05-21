import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@MainActor
@Test func coordinatorPersistWindowGeometryWritesLatestFrame() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    let coordinator = WindowPersistenceCoordinator(configStore: store)
    let frame = NSRect(x: 444, y: 555, width: 777, height: 888)

    coordinator.persistWindowFrameNow(frame, basedOn: .default)

    let loaded = store.load()
    #expect(loaded.windowX == 444)
    #expect(loaded.windowY == 555)
    #expect(loaded.windowWidth == 777)
    #expect(loaded.windowHeight == 888)
}

@MainActor
@Test func coordinatorPersistNowWritesImmediately() throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var saveCount = 0
    let coordinator = WindowPersistenceCoordinator(configStore: store) { _ in
        saveCount += 1
    }

    var cfg = ReaderConfig.default
    cfg.windowX = 901
    cfg.windowY = 902

    coordinator.persistNow(cfg)

    let loaded = store.load()
    #expect(loaded.windowX == 901)
    #expect(loaded.windowY == 902)
    #expect(saveCount == 1)
}

@MainActor
@Test func coordinatorDebouncedCoalescesRapidWrites() async throws {
    let fm = FileManager.default
    let tempRoot = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let store = ConfigStore(baseURL: tempRoot)
    var saveCount = 0
    let coordinator = WindowPersistenceCoordinator(
        configStore: store,
        debounceDelayNanos: 50_000_000,
    ) { _ in
        saveCount += 1
    }

    var cfg = ReaderConfig.default
    cfg.windowWidth = 1234

    coordinator.persistDebounced(cfg)
    coordinator.persistDebounced(cfg)
    coordinator.persistDebounced(cfg)

    try await Task.sleep(for: .milliseconds(1800))

    #expect(saveCount == 1)
    #expect(store.load().windowWidth == 1234)
}
