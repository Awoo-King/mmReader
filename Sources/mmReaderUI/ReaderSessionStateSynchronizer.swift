import Foundation
import mmReaderCore

public struct ReaderSessionSnapshot {
    public let documentPath: String?
    public let anchor: Int
    public let config: ReaderConfig
    public let pageIndex: Int
    public let totalPages: Int
    public let pageText: String
}

public enum ReaderSessionStateSynchronizer {
    public static func makeSnapshot(session: ReaderDocumentSession, configStore: ConfigStore) -> ReaderSessionSnapshot {
        ReaderSessionSnapshot(
            documentPath: session.currentDocumentPath,
            anchor: session.currentAnchor,
            config: session.currentConfig,
            pageIndex: session.currentPageIndex,
            totalPages: session.totalPages,
            pageText: session.currentPageText
        )
    }
}
