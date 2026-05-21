import Foundation
import Testing
@testable import mmReaderCore
@testable import mmReaderUI

@MainActor
@Test func dependenciesFactoryBuildsCoherentDependencySet() {
    let store = ConfigStore(baseURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
    let deps = ReaderWindowDependenciesFactory.make(configStore: store, saveObserver: nil as ((ReaderConfig) -> Void)?)

    #expect(deps.controllerState.config.windowWidth == ReaderConfig.default.windowWidth)
}
