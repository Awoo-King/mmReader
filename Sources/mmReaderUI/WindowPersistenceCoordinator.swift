import Foundation
import mmReaderCore

@MainActor
public final class WindowPersistenceCoordinator {
    private let configStore: ConfigStore
    private let saveObserver: ((ReaderConfig) -> Void)?
    private var pendingSaveTask: Task<Void, Never>?
    private let debounceDelayNanos: UInt64

    public init(
        configStore: ConfigStore,
        debounceDelayNanos: UInt64 = 250_000_000,
        saveObserver: ((ReaderConfig) -> Void)? = nil
    ) {
        self.configStore = configStore
        self.debounceDelayNanos = debounceDelayNanos
        self.saveObserver = saveObserver
    }

    public func persistNow(_ config: ReaderConfig) {
        pendingSaveTask?.cancel()
        configStore.save(config)
        saveObserver?(config)
    }

    public func persistDebounced(_ config: ReaderConfig) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task.detached { [weak self, config, debounceDelayNanos] in
            try? await Task.sleep(nanoseconds: debounceDelayNanos)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.persistNow(config)
            }
        }
    }

    public func persistWindowFrameNow(_ frame: CGRect, basedOn config: ReaderConfig) {
        var updated = config
        updated.windowX = frame.origin.x
        updated.windowY = frame.origin.y
        updated.windowWidth = frame.size.width
        updated.windowHeight = frame.size.height
        persistNow(updated)
    }

    public func persistWindowFrameDebounced(_ frame: CGRect, basedOn config: ReaderConfig) {
        var updated = config
        updated.windowX = frame.origin.x
        updated.windowY = frame.origin.y
        updated.windowWidth = frame.size.width
        updated.windowHeight = frame.size.height
        persistDebounced(updated)
    }
}
