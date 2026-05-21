import Foundation

public struct ReaderWindowLifecycleCoordinator {
    public init() {}

    public func restore(into state: inout ReaderControllerState, via interactor: inout ReaderSessionInteractor) {
        let snapshot = interactor.restore()
        state.apply(snapshot: snapshot)
    }

    public func handleDrop(_ url: URL, state: inout ReaderControllerState, interactor: inout ReaderSessionInteractor) -> Bool {
        let (handled, snapshot) = interactor.handleDroppedFile(url)
        if handled {
            state.apply(snapshot: snapshot)
        }
        return handled
    }

    public func moveToNextPage(state: inout ReaderControllerState, interactor: inout ReaderSessionInteractor) -> Bool {
        let (moved, snapshot) = interactor.moveToNextPage()
        if moved {
            state.apply(snapshot: snapshot)
        }
        return moved
    }

    public func moveToPreviousPage(state: inout ReaderControllerState, interactor: inout ReaderSessionInteractor) -> Bool {
        let (moved, snapshot) = interactor.moveToPreviousPage()
        if moved {
            state.apply(snapshot: snapshot)
        }
        return moved
    }
}
