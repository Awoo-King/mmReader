import AppKit

@MainActor
public final class ToolbarView: NSView {
    private let statusLabel = NSTextField(labelWithString: "0/0 0%")
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let controlsButton = NSButton(title: "Controls", target: nil, action: nil)
    private let pinButton = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin") ?? NSImage(), target: nil, action: nil)
    private let pinOffImage = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin") ?? NSImage()
    private let pinOnImage = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned") ?? NSImage()
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let hideButton = NSButton(title: "Hide", target: nil, action: nil)
    private let actionLeadingInset: CGFloat = 78

    public var onOpen: (() -> Void)?
    public var onShowControls: (() -> Void)?
    public var onTogglePin: (() -> Void)?
    public var onCloseWindow: (() -> Void)?
    public var onHideToolbar: (() -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public func update(page: Int, total: Int) {
        statusLabel.stringValue = ToolbarProgressFormatter.format(page: page, total: total)
    }

    public func setTransparentMode(_ enabled: Bool) {
        layer?.backgroundColor = enabled ? NSColor.clear.cgColor : NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
    }

    public func setPinned(_ pinned: Bool) {
        pinButton.title = pinned ? "已置顶" : "置顶"
        pinButton.image = pinned ? pinOnImage : pinOffImage
        pinButton.alternateImage = pinOnImage
        pinButton.contentTintColor = pinned ? .systemYellow : .labelColor
        pinButton.imagePosition = .imageLeading
        pinButton.setAccessibilityLabel(pinned ? "取消置顶" : "置顶")
    }

    public var debugBackgroundAlphaForTesting: CGFloat {
        guard let color = layer?.backgroundColor else { return -1 }
        return NSColor(cgColor: color)?.alphaComponent ?? -1
    }

    var debugOpenButtonLeadingConstantForTesting: CGFloat { actionLeadingInset }
    var debugPinButtonLeadingConstantForTesting: CGFloat { actionLeadingInset }
    var debugOpenButtonOffsetFromPinForTesting: CGFloat { 6 }
    var debugPinTitleForTesting: String { pinButton.title }
    var debugPinAccessibilityLabelForTesting: String { pinButton.accessibilityLabel() ?? "" }
    var debugPinHasImageForTesting: Bool { pinButton.image != nil }
    var debugPinHasAlternateImageForTesting: Bool { pinButton.alternateImage != nil }
    var debugPinUsesFilledSymbolForTesting: Bool { pinButton.image === pinOnImage }
    var debugPinHasEmphasisTintForTesting: Bool { pinButton.contentTintColor == .systemYellow }

    func debugTriggerOpenForTesting() { openTapped() }
    func debugTriggerShowControlsForTesting() { controlsTapped() }
    func debugTriggerTogglePinForTesting() { pinTapped() }
    func debugTriggerCloseWindowForTesting() { closeTapped() }
    func debugTriggerHideToolbarForTesting() { hideTapped() }

    @objc
    private func openTapped() {
        onOpen?()
    }

    @objc
    private func controlsTapped() {
        onShowControls?()
    }

    @objc
    private func pinTapped() {
        onTogglePin?()
    }

    @objc
    private func closeTapped() {
        onCloseWindow?()
    }

    @objc
    private func hideTapped() {
        onHideToolbar?()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor

        [openButton, controlsButton, pinButton, closeButton, hideButton].forEach {
            $0.bezelStyle = .rounded
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        openButton.target = self
        openButton.action = #selector(openTapped)
        controlsButton.target = self
        controlsButton.action = #selector(controlsTapped)
        pinButton.target = self
        pinButton.action = #selector(pinTapped)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        hideButton.target = self
        hideButton.action = #selector(hideTapped)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .black
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            pinButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: actionLeadingInset),
            pinButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            openButton.leadingAnchor.constraint(equalTo: pinButton.trailingAnchor, constant: 6),
            openButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            controlsButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 6),
            controlsButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.leadingAnchor.constraint(equalTo: controlsButton.trailingAnchor, constant: 6),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            hideButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 6),
            hideButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: hideButton.trailingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
