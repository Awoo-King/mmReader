import mmReaderCore

public struct ReaderControllerState {
    public private(set) var currentDocumentPath: String?
    public private(set) var currentAnchor: Int
    public private(set) var currentPageIndex: Int
    public private(set) var totalPages: Int
    public private(set) var currentPageText: String
    public var config: ReaderConfig

    public init(
        config: ReaderConfig,
        currentDocumentPath: String? = nil,
        currentAnchor: Int = 0,
        currentPageIndex: Int = 0,
        totalPages: Int = 0,
        currentPageText: String = ""
    ) {
        self.config = config
        self.currentDocumentPath = currentDocumentPath
        self.currentAnchor = currentAnchor
        self.currentPageIndex = currentPageIndex
        self.totalPages = totalPages
        self.currentPageText = currentPageText
    }

    public mutating func apply(snapshot: ReaderSessionSnapshot) {
        currentDocumentPath = snapshot.documentPath
        currentAnchor = snapshot.anchor
        currentPageIndex = snapshot.pageIndex
        totalPages = snapshot.totalPages
        currentPageText = snapshot.pageText
        config = snapshot.config
    }
}
