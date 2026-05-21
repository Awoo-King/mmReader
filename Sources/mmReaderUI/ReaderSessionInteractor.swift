import Foundation
import mmReaderCore

public struct ReaderSessionInteractor {
    private var session: ReaderDocumentSession
    private let configStore: ConfigStore

    public init(configStore: ConfigStore) {
        self.configStore = configStore
        self.session = ReaderDocumentSession(configStore: configStore)
    }

    public mutating func restore() -> ReaderSessionSnapshot {
        session.restoreFromConfig()
        return ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
    }

    public mutating func handleDroppedFile(_ url: URL) -> (Bool, ReaderSessionSnapshot) {
        let handled = session.handleDroppedFile(url)
        let snapshot = ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
        return (handled, snapshot)
    }

    public mutating func moveToNextPage() -> (Bool, ReaderSessionSnapshot) {
        let moved = session.moveToNextPage()
        let snapshot = ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
        return (moved, snapshot)
    }

    public mutating func moveToPreviousPage() -> (Bool, ReaderSessionSnapshot) {
        let moved = session.moveToPreviousPage()
        let snapshot = ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
        return (moved, snapshot)
    }

    public mutating func updateLinesPerPage(_ value: Int) -> ReaderSessionSnapshot {
        session.updateLinesPerPage(value)
        return ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
    }

    public mutating func updatePagination(linesPerPage: Int?, fontSize: Double?, windowWidth: Double?) -> ReaderSessionSnapshot {
        session.updatePagination(linesPerPage: linesPerPage, fontSize: fontSize, windowWidth: windowWidth)
        return ReaderSessionStateSynchronizer.makeSnapshot(session: session, configStore: configStore)
    }
}
