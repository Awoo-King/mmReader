import AppKit
import mmReaderCore

@MainActor
public final class ReaderControlsPopoverView: NSView {
    private let fontSlider = NSSlider(value: 18, minValue: 8, maxValue: 48, target: nil, action: nil)
    private let linesSlider = NSSlider(value: 30, minValue: 1, maxValue: 80, target: nil, action: nil)
    private let textAlphaSlider = NSSlider(value: 1.0, minValue: 0.01, maxValue: 1.0, target: nil, action: nil)
    private let backgroundAlphaSlider = NSSlider(value: 0.85, minValue: 0.01, maxValue: 1.0, target: nil, action: nil)
    private let textColorHexLabel = NSTextField(labelWithString: "HEX")
    private let textColorHexField = NSTextField(string: "#000000")
    private let textColorRLabel = NSTextField(labelWithString: "R")
    private let textColorRField = NSTextField(string: "0")
    private let textColorGLabel = NSTextField(labelWithString: "G")
    private let textColorGField = NSTextField(string: "0")
    private let textColorBLabel = NSTextField(labelWithString: "B")
    private let textColorBField = NSTextField(string: "0")
    private let shellModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let closeBehaviorPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontLabel = NSTextField(labelWithString: "字号")
    private let linesLabel = NSTextField(labelWithString: "行数")
    private let textAlphaLabel = NSTextField(labelWithString: "文字")
    private let bgAlphaLabel = NSTextField(labelWithString: "背景")
    private let shellModeLabel = NSTextField(labelWithString: "模式")
    private let closeBehaviorLabel = NSTextField(labelWithString: "关闭")
    private let fontValueLabel = NSTextField(labelWithString: "18")
    private let linesValueLabel = NSTextField(labelWithString: "30")
    private let textAlphaValueLabel = NSTextField(labelWithString: "100%")
    private let backgroundAlphaValueLabel = NSTextField(labelWithString: "85%")
    private let shortcutScrollView = NSScrollView()
    public let shortcutSettingsView = ShortcutSettingsView(frame: .init(x: 0, y: 0, width: 220, height: 220))

    public var onFontSizeChanged: ((Double) -> Void)?
    public var onLinesPerPageChanged: ((Int) -> Void)?
    public var onTextAlphaChanged: ((Double) -> Void)?
    public var onBackgroundAlphaChanged: ((Double) -> Void)?
    public var onTextColorHexChanged: ((String) -> Void)?
    public var onShellModeChanged: ((ReaderShellMode) -> Void)?
    public var onCloseBehaviorChanged: ((ReaderCloseBehavior) -> Void)?

    var debugFontValueTextForTesting: String { fontValueLabel.stringValue }
    var debugLinesValueTextForTesting: String { linesValueLabel.stringValue }
    var debugTextAlphaValueTextForTesting: String { textAlphaValueLabel.stringValue }
    var debugBackgroundAlphaValueTextForTesting: String { backgroundAlphaValueLabel.stringValue }
    var debugTextColorHexForTesting: String { textColorHexField.stringValue }
    var debugFontMinimumForTesting: Double { fontSlider.minValue }
    var debugLinesMinimumForTesting: Double { linesSlider.minValue }
    var debugTextAlphaMinimumForTesting: Double { textAlphaSlider.minValue }
    var debugBackgroundAlphaMinimumForTesting: Double { backgroundAlphaSlider.minValue }
    var debugShortcutScrollWidthForTesting: CGFloat { shortcutScrollView.contentSize.width }

    func debugSectionLabelsForTesting() -> [String] {
        [fontLabel, linesLabel, textAlphaLabel, bgAlphaLabel, shellModeLabel, closeBehaviorLabel].map(\.stringValue)
    }

    func debugColorFieldLabelsForTesting() -> [String] {
        [textColorHexLabel, textColorRLabel, textColorGLabel, textColorBLabel].map(\.stringValue)
    }

    func debugSetTextColorHexForTesting(_ value: String) {
        textColorHexField.stringValue = value
        textColorHexChanged()
    }

    func debugSetTextColorRGBForTesting(r: Int, g: Int, b: Int) {
        textColorRField.stringValue = String(r)
        textColorGField.stringValue = String(g)
        textColorBField.stringValue = String(b)
        textColorRGBChanged()
    }

    func debugTextColorRgbForTesting() -> (Int, Int, Int) {
        (
            Int(textColorRField.stringValue) ?? -1,
            Int(textColorGField.stringValue) ?? -1,
            Int(textColorBField.stringValue) ?? -1
        )
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public func apply(fontSize: Double, linesPerPage: Int, textAlpha: Double, backgroundAlpha: Double, textColorHex: String, shortcuts: ReaderShortcutBindings) {
        fontSlider.doubleValue = fontSize
        linesSlider.doubleValue = Double(linesPerPage)
        textAlphaSlider.doubleValue = textAlpha
        backgroundAlphaSlider.doubleValue = backgroundAlpha
        setTextColorHex(textColorHex)
        shortcutSettingsView.apply(shortcuts: shortcuts)
        updateValueLabels()
    }

    func debugSetFontSizeForTesting(_ value: Double) {
        fontSlider.doubleValue = value
        fontSizeChanged()
    }

    func debugSetLinesPerPageForTesting(_ value: Int) {
        linesSlider.doubleValue = Double(value)
        linesChanged()
    }

    func debugSetTextAlphaForTesting(_ value: Double) {
        textAlphaSlider.doubleValue = value
        textAlphaChanged()
    }

    func debugSetBackgroundAlphaForTesting(_ value: Double) {
        backgroundAlphaSlider.doubleValue = value
        backgroundAlphaChanged()
    }

    func debugSetShellModeForTesting(_ mode: ReaderShellMode) {
        switch mode {
        case .dockOnly: shellModePopup.selectItem(at: 0)
        case .statusItemOnly: shellModePopup.selectItem(at: 1)
        case .dockAndStatusItem: shellModePopup.selectItem(at: 2)
        }
        shellModeChanged()
    }

    func debugSetCloseBehaviorForTesting(_ behavior: ReaderCloseBehavior) {
        switch behavior {
        case .hideWindow: closeBehaviorPopup.selectItem(at: 0)
        case .quitApp: closeBehaviorPopup.selectItem(at: 1)
        }
        closeBehaviorChanged()
    }

    @objc
    private func fontSizeChanged() {
        updateValueLabels()
        onFontSizeChanged?(fontSlider.doubleValue)
    }

    @objc
    private func linesChanged() {
        updateValueLabels()
        onLinesPerPageChanged?(Int(linesSlider.doubleValue.rounded()))
    }

    @objc
    private func textAlphaChanged() {
        updateValueLabels()
        onTextAlphaChanged?(textAlphaSlider.doubleValue)
    }

    @objc
    private func backgroundAlphaChanged() {
        updateValueLabels()
        onBackgroundAlphaChanged?(backgroundAlphaSlider.doubleValue)
    }

    @objc
    private func textColorHexChanged() {
        guard let normalized = normalizedHex(textColorHexField.stringValue) else { return }
        setTextColorHex(normalized)
        onTextColorHexChanged?(normalized)
    }

    @objc
    private func textColorRGBChanged() {
        guard let r = Int(textColorRField.stringValue),
              let g = Int(textColorGField.stringValue),
              let b = Int(textColorBField.stringValue),
              (0...255).contains(r),
              (0...255).contains(g),
              (0...255).contains(b) else { return }
        let hexValue = hex(r: r, g: g, b: b)
        setTextColorHex(hexValue)
        onTextColorHexChanged?(hexValue)
    }

    @objc
    private func shellModeChanged() {
        switch shellModePopup.indexOfSelectedItem {
        case 0: onShellModeChanged?(.dockOnly)
        case 1: onShellModeChanged?(.statusItemOnly)
        default: onShellModeChanged?(.dockAndStatusItem)
        }
    }

    @objc
    private func closeBehaviorChanged() {
        switch closeBehaviorPopup.indexOfSelectedItem {
        case 0: onCloseBehaviorChanged?(.hideWindow)
        default: onCloseBehaviorChanged?(.quitApp)
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor

        shellModePopup.addItems(withTitles: ["仅停靠栏", "仅状态栏", "停靠栏和状态栏"])
        closeBehaviorPopup.addItems(withTitles: ["隐藏窗口", "退出应用"])

        [
            fontLabel, linesLabel, textAlphaLabel, bgAlphaLabel, shellModeLabel, closeBehaviorLabel,
            fontSlider, linesSlider, textAlphaSlider, backgroundAlphaSlider,
            fontValueLabel, linesValueLabel, textAlphaValueLabel, backgroundAlphaValueLabel,
            shellModePopup, closeBehaviorPopup, shortcutScrollView,
            textColorHexLabel, textColorHexField,
            textColorRLabel, textColorRField,
            textColorGLabel, textColorGField,
            textColorBLabel, textColorBField
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        shortcutScrollView.translatesAutoresizingMaskIntoConstraints = false
        shortcutScrollView.borderType = .noBorder
        shortcutScrollView.hasVerticalScroller = true
        shortcutScrollView.drawsBackground = false
        shortcutScrollView.documentView = shortcutSettingsView

        fontSlider.target = self
        fontSlider.action = #selector(fontSizeChanged)
        linesSlider.target = self
        linesSlider.action = #selector(linesChanged)
        textAlphaSlider.target = self
        textAlphaSlider.action = #selector(textAlphaChanged)
        backgroundAlphaSlider.target = self
        backgroundAlphaSlider.action = #selector(backgroundAlphaChanged)
        shellModePopup.target = self
        shellModePopup.action = #selector(shellModeChanged)
        textColorHexField.target = self
        textColorHexField.action = #selector(textColorHexChanged)
        textColorRField.target = self
        textColorRField.action = #selector(textColorRGBChanged)
        textColorGField.target = self
        textColorGField.action = #selector(textColorRGBChanged)
        textColorBField.target = self
        textColorBField.action = #selector(textColorRGBChanged)

        NSLayoutConstraint.activate([
            fontLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            fontLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            fontSlider.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 8),
            fontSlider.trailingAnchor.constraint(equalTo: fontValueLabel.leadingAnchor, constant: -8),
            fontSlider.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            fontValueLabel.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),

            linesLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            linesLabel.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: 12),
            linesSlider.leadingAnchor.constraint(equalTo: linesLabel.trailingAnchor, constant: 8),
            linesSlider.trailingAnchor.constraint(equalTo: linesValueLabel.leadingAnchor, constant: -8),
            linesSlider.centerYAnchor.constraint(equalTo: linesLabel.centerYAnchor),
            linesValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            linesValueLabel.centerYAnchor.constraint(equalTo: linesLabel.centerYAnchor),

            textAlphaLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textAlphaLabel.topAnchor.constraint(equalTo: linesLabel.bottomAnchor, constant: 12),
            textAlphaSlider.leadingAnchor.constraint(equalTo: textAlphaLabel.trailingAnchor, constant: 8),
            textAlphaSlider.trailingAnchor.constraint(equalTo: textAlphaValueLabel.leadingAnchor, constant: -8),
            textAlphaSlider.centerYAnchor.constraint(equalTo: textAlphaLabel.centerYAnchor),
            textAlphaValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textAlphaValueLabel.centerYAnchor.constraint(equalTo: textAlphaLabel.centerYAnchor),

            bgAlphaLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            bgAlphaLabel.topAnchor.constraint(equalTo: textAlphaLabel.bottomAnchor, constant: 12),
            backgroundAlphaSlider.leadingAnchor.constraint(equalTo: bgAlphaLabel.trailingAnchor, constant: 8),
            backgroundAlphaSlider.trailingAnchor.constraint(equalTo: backgroundAlphaValueLabel.leadingAnchor, constant: -8),
            backgroundAlphaSlider.centerYAnchor.constraint(equalTo: bgAlphaLabel.centerYAnchor),
            backgroundAlphaValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            backgroundAlphaValueLabel.centerYAnchor.constraint(equalTo: bgAlphaLabel.centerYAnchor),

            shellModeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            shellModeLabel.topAnchor.constraint(equalTo: bgAlphaLabel.bottomAnchor, constant: 14),
            shellModePopup.leadingAnchor.constraint(equalTo: shellModeLabel.trailingAnchor, constant: 8),
            shellModePopup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            shellModePopup.centerYAnchor.constraint(equalTo: shellModeLabel.centerYAnchor),

            closeBehaviorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            closeBehaviorLabel.topAnchor.constraint(equalTo: shellModeLabel.bottomAnchor, constant: 12),
            closeBehaviorPopup.leadingAnchor.constraint(equalTo: closeBehaviorLabel.trailingAnchor, constant: 8),
            closeBehaviorPopup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            closeBehaviorPopup.centerYAnchor.constraint(equalTo: closeBehaviorLabel.centerYAnchor),

            textColorHexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textColorHexLabel.topAnchor.constraint(equalTo: closeBehaviorLabel.bottomAnchor, constant: 14),
            textColorHexField.leadingAnchor.constraint(equalTo: textColorHexLabel.trailingAnchor, constant: 8),
            textColorHexField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textColorHexField.centerYAnchor.constraint(equalTo: textColorHexLabel.centerYAnchor),

            textColorRLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textColorRLabel.topAnchor.constraint(equalTo: textColorHexLabel.bottomAnchor, constant: 12),
            textColorRField.leadingAnchor.constraint(equalTo: textColorRLabel.trailingAnchor, constant: 8),
            textColorRField.widthAnchor.constraint(equalToConstant: 50),
            textColorRField.centerYAnchor.constraint(equalTo: textColorRLabel.centerYAnchor),

            textColorGLabel.leadingAnchor.constraint(equalTo: textColorRField.trailingAnchor, constant: 10),
            textColorGLabel.centerYAnchor.constraint(equalTo: textColorRLabel.centerYAnchor),
            textColorGField.leadingAnchor.constraint(equalTo: textColorGLabel.trailingAnchor, constant: 8),
            textColorGField.widthAnchor.constraint(equalToConstant: 50),
            textColorGField.centerYAnchor.constraint(equalTo: textColorGLabel.centerYAnchor),

            textColorBLabel.leadingAnchor.constraint(equalTo: textColorGField.trailingAnchor, constant: 10),
            textColorBLabel.centerYAnchor.constraint(equalTo: textColorRLabel.centerYAnchor),
            textColorBField.leadingAnchor.constraint(equalTo: textColorBLabel.trailingAnchor, constant: 8),
            textColorBField.widthAnchor.constraint(equalToConstant: 50),
            textColorBField.centerYAnchor.constraint(equalTo: textColorBLabel.centerYAnchor),

            shortcutScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            shortcutScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            shortcutScrollView.topAnchor.constraint(equalTo: textColorRLabel.bottomAnchor, constant: 16),
            shortcutScrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            shortcutScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])

        updateValueLabels()
    }

    private func updateValueLabels() {
        fontValueLabel.stringValue = String(Int(fontSlider.doubleValue.rounded()))
        linesValueLabel.stringValue = String(Int(linesSlider.doubleValue.rounded()))
        textAlphaValueLabel.stringValue = "\(Int((textAlphaSlider.doubleValue * 100).rounded()))%"
        backgroundAlphaValueLabel.stringValue = "\(Int((backgroundAlphaSlider.doubleValue * 100).rounded()))%"
    }

    private func setTextColorHex(_ hex: String) {
        textColorHexField.stringValue = hex
        if let (r, g, b) = rgb(from: hex) {
            textColorRField.stringValue = String(r)
            textColorGField.stringValue = String(g)
            textColorBField.stringValue = String(b)
        }
    }

    private func normalizedHex(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let value = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard value.count == 6, Int(value, radix: 16) != nil else { return nil }
        return "#\(value)"
    }

    private func rgb(from hex: String) -> (Int, Int, Int)? {
        guard let normalized = normalizedHex(hex) else { return nil }
        let value = String(normalized.dropFirst())
        guard let rgb = Int(value, radix: 16) else { return nil }
        return ((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
    }

    private func hex(r: Int, g: Int, b: Int) -> String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
}
