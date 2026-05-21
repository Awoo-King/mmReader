import AppKit

@MainActor
final class ReaderTextView: NSTextView {
    override var mouseDownCanMoveWindow: Bool { true }
}

@MainActor
public final class ReaderView: NSView {
    private let textView: NSTextView
    private var currentText = ""
    private var currentFontSize: Double = 18
    private var currentTextAlpha: Double = 1.0
    private var currentTextColorHex = "#000000"

    public override init(frame frameRect: NSRect) {
        self.textView = ReaderTextView(frame: .zero)
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        self.textView = ReaderTextView(frame: .zero)
        super.init(coder: coder)
        setup()
    }

    public func setText(_ text: String) {
        currentText = text
        renderText()
    }

    public func applyFontSize(_ size: Double) {
        currentFontSize = size
        renderText()
    }

    public func applyTextAlpha(_ alpha: Double) {
        currentTextAlpha = alpha
        renderText()
    }

    public func applyTextColorHex(_ hex: String) {
        currentTextColorHex = hex
        renderText()
    }

    public var debugTextValueForTesting: String {
        textView.string
    }

    public var debugDrawsBackgroundForTesting: Bool {
        textView.drawsBackground
    }

    public var debugFontSizeForTesting: Double {
        currentFontSize
    }

    public var debugFontWeightForTesting: Int {
        guard let font = textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont else {
            return -1
        }
        return font.fontDescriptor.symbolicTraits.contains(.bold) ? 1 : 0
    }

    public var debugTextAlphaForTesting: Double {
        currentTextAlpha
    }

    public var debugHasShadowForTesting: Bool {
        guard textView.string.isEmpty == false,
              let shadow = textView.textStorage?.attribute(.shadow, at: 0, effectiveRange: nil) as? NSShadow else {
            return false
        }
        return shadow.shadowBlurRadius > 0 || shadow.shadowOffset != .zero || shadow.shadowColor != nil
    }

    public var debugTextColorHexForTesting: String {
        currentTextColorHex
    }

    public var displayedText: String {
        textView.string
    }

    private func setup() {
        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.heightTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 0
            textView.defaultParagraphStyle = style
        }
        renderText()

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func renderText() {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: currentFontSize, weight: .regular),
            .foregroundColor: color(from: currentTextColorHex).withAlphaComponent(currentTextAlpha),
            .paragraphStyle: style
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: currentText, attributes: attributes))
    }

    private func color(from hex: String) -> NSColor {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 7, normalized.hasPrefix("#") else { return .labelColor }
        let value = String(normalized.dropFirst())
        guard let rgb = Int(value, radix: 16) else { return .labelColor }
        return NSColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
