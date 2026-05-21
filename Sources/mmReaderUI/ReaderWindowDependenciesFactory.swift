import mmReaderCore

public struct ReaderWindowDependencies {
    public let controllerState: ReaderControllerState
    public let sessionInteractor: ReaderSessionInteractor
    public let persistenceCoordinator: WindowPersistenceCoordinator
}

@MainActor
public enum ReaderWindowDependenciesFactory {
    public static func make(
        configStore: ConfigStore,
        saveObserver: ((ReaderConfig) -> Void)?
    ) -> ReaderWindowDependencies {
        let initialConfig = configStore.load()
        return ReaderWindowDependencies(
            controllerState: ReaderControllerState(config: initialConfig),
            sessionInteractor: ReaderSessionInteractor(configStore: configStore),
            persistenceCoordinator: WindowPersistenceCoordinator(
                configStore: configStore,
                saveObserver: saveObserver
            )
        )
    }
}
