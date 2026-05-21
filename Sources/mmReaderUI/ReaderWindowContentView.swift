import AppKit

@MainActor
public final class ReaderWindowContentView: NSView {
    public let readerView: ReaderView
    public let toolbarView: ToolbarView
    public let controlsView: ReaderControlsPopoverView
    var fileDropHandler: ((URL) -> Bool)?

    public override init(frame frameRect: NSRect) {
        self.readerView = ReaderView(frame: .zero)
        self.toolbarView = ToolbarView(frame: .zero)
        self.controlsView = ReaderControlsPopoverView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        self.readerView = ReaderView(frame: .zero)
        self.toolbarView = ToolbarView(frame: .zero)
        self.controlsView = ReaderControlsPopoverView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        super.init(coder: coder)
        setup()
    }

    public func setText(_ text: String) {
        readerView.setText(text)
    }

    public var displayedTextForTesting: String {
        readerView.displayedText
    }

    var debugHasInlineControlsForTesting: Bool {
        controlsView.superview === self
    }

    public func setToolbarTransparent(_ enabled: Bool) {
        toolbarView.setTransparentMode(enabled)
    }

    func handleDroppedFileURL(_ url: URL) -> Bool {
        fileDropHandler?(url) ?? false
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard extractDroppedFileURL(from: sender) != nil else { return [] }
        return .copy
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = extractDroppedFileURL(from: sender) else { return false }
        return handleDroppedFileURL(url)
    }

    private func setup() {
        registerForDraggedTypes([.fileURL])
        controlsView.isHidden = false
        translatesAutoresizingMaskIntoConstraints = false
        readerView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(readerView)
        addSubview(toolbarView)

        NSLayoutConstraint.activate([
            toolbarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarView.topAnchor.constraint(equalTo: topAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 30),

            readerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            readerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            readerView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            readerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func extractDroppedFileURL(from sender: NSDraggingInfo) -> URL? {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return sender.draggingPasteboard.readObjects(forClasses: classes, options: options)?.first as? URL
    }
}
