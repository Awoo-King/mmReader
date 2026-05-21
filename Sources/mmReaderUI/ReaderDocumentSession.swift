import Foundation
import mmReaderCore

public struct ReaderDocumentSession {
    public private(set) var currentDocumentPath: String?
    public private(set) var currentAnchor: Int
    public private(set) var currentPageIndex: Int
    public private(set) var totalPages: Int
    public private(set) var currentPageText: String
    public var currentConfig: ReaderConfig { config }

    private let configStore: ConfigStore
    private var config: ReaderConfig
    private var engine: ReaderEngine

    public init(configStore: ConfigStore) {
        self.configStore = configStore
        self.config = configStore.load()
        self.engine = ReaderEngine(
            linesPerPage: config.linesPerPage,
            layoutWidth: Self.contentWidth(for: config.windowWidth),
            fontSize: config.fontSize
        )
        self.currentDocumentPath = nil
        self.currentAnchor = 0
        self.currentPageIndex = 0
        self.totalPages = 0
        self.currentPageText = ""
    }

    public mutating func restoreFromConfig() {
        guard let path = config.lastFilePath else { return }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }

        do {
            engine.configurePagination(
                linesPerPage: config.linesPerPage,
                layoutWidth: Self.contentWidth(for: config.windowWidth),
                fontSize: config.fontSize
            )
            try engine.openFileAtomically(url)
            if let anchor = config.lastAnchor {
                engine.goToAnchor(anchor)
            } else {
                engine.goToPage(config.lastPageIndex)
            }
            currentDocumentPath = path
            syncDerivedStateFromEngine()
        } catch {
            return
        }
    }

    @discardableResult
    public mutating func handleDroppedFile(_ url: URL) -> Bool {
        do {
            engine.configurePagination(
                linesPerPage: config.linesPerPage,
                layoutWidth: Self.contentWidth(for: config.windowWidth),
                fontSize: config.fontSize
            )
            try engine.openFileAtomically(url)
            currentDocumentPath = url.path
            syncDerivedStateFromEngine()
            persistCurrentPosition()
            return true
        } catch {
            return false
        }
    }

    public mutating func moveToNextPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex < totalPages - 1 else { return false }
        engine.goToPage(currentPageIndex + 1)
        syncDerivedStateFromEngine()
        persistCurrentPosition()
        return true
    }

    public mutating func moveToPreviousPage() -> Bool {
        guard totalPages > 0 else { return false }
        guard currentPageIndex > 0 else { return false }
        engine.goToPage(currentPageIndex - 1)
        syncDerivedStateFromEngine()
        persistCurrentPosition()
        return true
    }

    public mutating func updateLinesPerPage(_ value: Int) {
        updatePagination(linesPerPage: value, fontSize: nil, windowWidth: nil)
    }

    public mutating func updatePagination(linesPerPage: Int?, fontSize: Double?, windowWidth: Double?) {
        if let linesPerPage {
            config.linesPerPage = max(1, linesPerPage)
        }
        if let fontSize {
            config.fontSize = fontSize
        }
        if let windowWidth {
            config.windowWidth = windowWidth
        }
        engine.configurePagination(
            linesPerPage: config.linesPerPage,
            layoutWidth: Self.contentWidth(for: config.windowWidth),
            fontSize: config.fontSize
        )
        syncDerivedStateFromEngine()
        persistCurrentPosition()
    }

    private static func contentWidth(for windowWidth: Double) -> Double {
        max(1, windowWidth - 24)
    }

    private mutating func syncDerivedStateFromEngine() {
        currentAnchor = engine.currentAnchor
        currentPageIndex = engine.currentPageIndex
        totalPages = engine.pages.count
        currentPageText = engine.pages[safe: engine.currentPageIndex] ?? ""
    }

    private mutating func persistCurrentPosition() {
        guard let currentDocumentPath else { return }
        config.lastFilePath = currentDocumentPath
        config.lastAnchor = currentAnchor
        config.lastPageIndex = currentPageIndex
        configStore.save(config)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
