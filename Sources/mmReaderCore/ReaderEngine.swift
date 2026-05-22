import AppKit
import Foundation

public enum ReaderEngineError: Error {
    case unsupportedFormat
}

public struct ReaderEngine {
    public private(set) var pages: [String] = []
    public private(set) var currentPageIndex: Int = 0
    public private(set) var currentAnchor: Int = 0

    private var linesPerPage: Int
    private var layoutWidth: Double
    private var fontSize: Double
    private var normalizedText: String = ""
    private var pageStartOffsets: [Int] = [0]

    public init(linesPerPage: Int = 30, layoutWidth: Double = 680, fontSize: Double = 18) {
        self.linesPerPage = max(1, linesPerPage)
        self.layoutWidth = max(1, layoutWidth)
        self.fontSize = max(1, fontSize)
    }

    public static func supports(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "txt" || ext == "md"
    }

    public mutating func load(url: URL) throws {
        guard Self.supports(url: url) else {
            throw ReaderEngineError.unsupportedFormat
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        try load(text: text)
    }

    public mutating func openFileAtomically(_ url: URL) throws {
        guard Self.supports(url: url) else {
            throw ReaderEngineError.unsupportedFormat
        }

        let data = try Data(contentsOf: url)
        let text = try decodeText(data)

        var candidate = self
        try candidate.load(text: text)
        self = candidate
    }

    public mutating func load(text: String) throws {
        normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        recalculatePages(keepingAnchor: nil)
        currentPageIndex = 0
        currentAnchor = 0
    }

    public mutating func repaginate(linesPerPage: Int) {
        configurePagination(linesPerPage: linesPerPage, layoutWidth: nil, fontSize: nil)
    }

    public mutating func configurePagination(linesPerPage: Int?, layoutWidth: Double?, fontSize: Double?) {
        if let linesPerPage {
            self.linesPerPage = max(1, linesPerPage)
        }
        if let layoutWidth {
            self.layoutWidth = max(1, layoutWidth)
        }
        if let fontSize {
            self.fontSize = max(1, fontSize)
        }
        guard normalizedText.isEmpty == false else { return }
        let anchor = currentAnchor
        recalculatePages(keepingAnchor: anchor)
    }

    public mutating func goToPage(_ index: Int) {
        guard !pages.isEmpty else {
            currentPageIndex = 0
            currentAnchor = 0
            return
        }
        currentPageIndex = min(max(index, 0), pages.count - 1)
        currentAnchor = anchorForPageIndex(currentPageIndex)
    }

    public mutating func goToAnchor(_ anchor: Int) {
        guard !pages.isEmpty else {
            currentPageIndex = 0
            currentAnchor = 0
            return
        }
        let clamped = clampedAnchor(anchor)
        currentPageIndex = pageIndex(forAnchor: clamped)
        currentAnchor = clamped
    }

    public mutating func goToFirstMeaningfulPage() {
        guard pages.isEmpty == false else {
            currentPageIndex = 0
            currentAnchor = 0
            return
        }

        for (index, page) in pages.enumerated() {
            if page.contains(where: { !$0.isWhitespace && !$0.isNewline }) {
                currentPageIndex = index
                currentAnchor = anchorForPageIndex(index)
                return
            }
        }

        currentPageIndex = 0
        currentAnchor = anchorForPageIndex(0)
    }

    private mutating func recalculatePages(keepingAnchor anchor: Int?) {
        let nsText = normalizedText as NSString
        pages = []
        pageStartOffsets = []

        guard nsText.length > 0 else {
            pages = [""]
            pageStartOffsets = [0]
            currentPageIndex = 0
            currentAnchor = 0
            return
        }

        let storage = NSTextStorage(
            string: normalizedText,
            attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .regular)]
        )
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: CGFloat(max(1, layoutWidth - 12)), height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let glyphRange = layoutManager.glyphRange(for: container)
        var visualLineStarts: [Int] = []
        var visualLineEnds: [Int] = []
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            _ = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            visualLineStarts.append(charRange.location)
            visualLineEnds.append(NSMaxRange(charRange))
            glyphIndex = NSMaxRange(lineGlyphRange)
        }

        if visualLineStarts.isEmpty {
            visualLineStarts = [0]
            visualLineEnds = [nsText.length]
        }

        var lineIndex = 0
        while lineIndex < visualLineStarts.count {
            let endLineIndex = min(lineIndex + linesPerPage, visualLineStarts.count)
            let startOffset = visualLineStarts[lineIndex]
            let endOffset = visualLineEnds[endLineIndex - 1]
            pageStartOffsets.append(startOffset)
            pages.append(nsText.substring(with: NSRange(location: startOffset, length: max(0, endOffset - startOffset))))
            lineIndex = endLineIndex
        }

        if let anchor {
            currentPageIndex = pageIndex(forAnchor: anchor)
            currentAnchor = clampedAnchor(anchorForPageIndex(currentPageIndex))
        } else {
            currentPageIndex = min(currentPageIndex, max(0, pages.count - 1))
            currentAnchor = anchorForPageIndex(currentPageIndex)
        }
    }

    private func pageIndex(forAnchor anchor: Int) -> Int {
        let clamped = clampedAnchor(anchor)
        guard !pageStartOffsets.isEmpty else { return 0 }

        var best = 0
        for (pageIdx, offset) in pageStartOffsets.enumerated() {
            if offset <= clamped {
                best = pageIdx
            } else {
                break
            }
        }
        return best
    }

    private func decodeText(_ data: Data) throws -> String {
        let encodings: [String.Encoding] = [
            .utf8,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GBK_95.rawValue))),
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5_E.rawValue))),
            .utf16,
            .unicode
        ]

        for encoding in encodings {
            guard let text = String(data: data, encoding: encoding) else { continue }
            guard looksLikeMojibake(text) == false else { continue }
            return text
        }

        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    private func looksLikeMojibake(_ text: String) -> Bool {
        guard text.isEmpty == false else { return false }
        let scalars = text.unicodeScalars
        let suspicious = scalars.filter {
            ($0.value >= 0xAC00 && $0.value <= 0xD7AF) || $0 == "�"
        }
        return suspicious.count * 5 > scalars.count
    }

    private func anchorForPageIndex(_ pageIndex: Int) -> Int {
        guard !pageStartOffsets.isEmpty else { return 0 }
        return pageStartOffsets[min(max(pageIndex, 0), pageStartOffsets.count - 1)]
    }

    private func clampedAnchor(_ anchor: Int) -> Int {
        let maxOffset = (normalizedText as NSString).length
        return max(0, min(anchor, maxOffset))
    }
}
