import AppKit
import mmReaderCore

@MainActor
final class ShortcutCaptureField: NSTextField {
    var onShortcutCaptured: ((ReaderShortcutBindings.Key) -> Void)?
    var formatShortcut: ((ReaderShortcutBindings.Key) -> String)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if captureShortcut(from: event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if captureShortcut(from: event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func captureShortcut(from event: NSEvent) -> Bool {
        guard let binding = shortcutBinding(from: event) else { return false }
        stringValue = formatShortcut?(binding) ?? ""
        onShortcutCaptured?(binding)
        return true
    }

    private func shortcutBinding(from event: NSEvent) -> ReaderShortcutBindings.Key? {
        let modifiers = modifierStrings(from: event.modifierFlags)
        guard let chars = event.charactersIgnoringModifiers, chars.isEmpty == false else { return nil }

        let key: String
        if chars == String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)) {
            key = "upArrow"
        } else if chars == String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)) {
            key = "downArrow"
        } else if chars == String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)) {
            key = "leftArrow"
        } else if chars == String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)) {
            key = "rightArrow"
        } else {
            key = chars.lowercased()
        }

        return .init(key: key, modifiers: modifiers)
    }

    private func modifierStrings(from flags: NSEvent.ModifierFlags) -> [String] {
        var result: [String] = []
        if flags.contains(.control) { result.append("control") }
        if flags.contains(.command) { result.append("command") }
        if flags.contains(.option) { result.append("option") }
        if flags.contains(.shift) { result.append("shift") }
        return result
    }
}

@MainActor
public final class ShortcutSettingsView: NSView {
    private let actionLabels = ["上一页", "下一页", "显隐工具栏", "打开文件", "关闭窗口", "显隐主窗口", "显隐 Controls", "切换置顶", "隐藏工具栏"]
    private var displayedBindings: [String: String] = [:]
    private var editors: [String: ShortcutCaptureField] = [:]
    public var onShortcutChanged: ((String, ReaderShortcutBindings.Key) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func debugActionLabelsForTesting() -> [String] {
        actionLabels
    }

    func debugDisplayedBindingForTesting(action: String) -> String {
        displayedBindings[action] ?? ""
    }

    func debugSetBindingTextForTesting(action: String, text: String) {
        editors[action]?.stringValue = text
        bindingChanged(for: action)
    }

    func debugPerformKeyEventForTesting(action: String, event: NSEvent) {
        _ = editors[action]?.performKeyEquivalent(with: event)
    }

    func debugUpdateShortcutForTesting(action: String, key: String, modifiers: [String]) {
        onShortcutChanged?(action, .init(key: key, modifiers: modifiers))
    }

    public func apply(shortcuts: ReaderShortcutBindings) {
        setDisplayedBinding(action: "上一页", binding: shortcuts.previousPage)
        setDisplayedBinding(action: "下一页", binding: shortcuts.nextPage)
        setDisplayedBinding(action: "显隐工具栏", binding: shortcuts.toggleToolbar)
        setDisplayedBinding(action: "打开文件", binding: shortcuts.openFile)
        setDisplayedBinding(action: "关闭窗口", binding: shortcuts.closeWindow)
        setDisplayedBinding(action: "显隐主窗口", binding: shortcuts.toggleMainWindow)
        setDisplayedBinding(action: "显隐 Controls", binding: shortcuts.toggleControls)
        setDisplayedBinding(action: "切换置顶", binding: shortcuts.togglePin)
        setDisplayedBinding(action: "隐藏工具栏", binding: shortcuts.hideToolbar)
    }

    private func setup() {
        var previousRowBottom: NSLayoutYAxisAnchor = topAnchor
        for (index, label) in actionLabels.enumerated() {
            let field = NSTextField(labelWithString: label)
            let editor = ShortcutCaptureField(string: "")
            field.translatesAutoresizingMaskIntoConstraints = false
            editor.translatesAutoresizingMaskIntoConstraints = false
            editor.tag = index
            editor.onShortcutCaptured = { [weak self] binding in
                guard let self else { return }
                let action = self.actionLabels[index]
                self.displayedBindings[action] = self.displayText(for: binding)
                self.editors[action]?.stringValue = self.displayText(for: binding)
                self.onShortcutChanged?(action, binding)
            }
            editor.formatShortcut = { [weak self] binding in
                self?.displayText(for: binding) ?? ""
            }
            editors[label] = editor
            addSubview(field)
            addSubview(editor)

            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                field.widthAnchor.constraint(equalToConstant: 90),
                field.topAnchor.constraint(equalTo: previousRowBottom, constant: index == 0 ? 10 : 8),
                editor.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8),
                editor.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                editor.centerYAnchor.constraint(equalTo: field.centerYAnchor),
                editor.heightAnchor.constraint(equalToConstant: 24)
            ])
            previousRowBottom = field.bottomAnchor
        }
    }

    @objc
    private func bindingEdited(_ sender: NSTextField) {
        let action = actionLabels[sender.tag]
        bindingChanged(for: action)
    }

    private func bindingChanged(for action: String) {
        guard let text = editors[action]?.stringValue,
              let binding = parseBinding(text) else { return }
        displayedBindings[action] = displayText(for: binding)
        editors[action]?.stringValue = displayText(for: binding)
        onShortcutChanged?(action, binding)
    }

    private func setDisplayedBinding(action: String, binding: ReaderShortcutBindings.Key) {
        let text = displayText(for: binding)
        displayedBindings[action] = text
        editors[action]?.stringValue = text
    }

    private func parseBinding(_ text: String) -> ReaderShortcutBindings.Key? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return nil }

        var modifiers: [String] = []
        if trimmed.contains("⌃") { modifiers.append("control") }
        if trimmed.contains("⌘") { modifiers.append("command") }
        if trimmed.contains("⌥") { modifiers.append("option") }
        if trimmed.contains("⇧") { modifiers.append("shift") }

        let key: String
        switch last {
        case "↑": key = "upArrow"
        case "↓": key = "downArrow"
        default: key = String(last).lowercased()
        }

        return .init(key: key, modifiers: modifiers)
    }

    private func displayText(for binding: ReaderShortcutBindings.Key) -> String {
        let modifierOrder = ["control", "option", "shift", "command"]
        let modifiers = modifierOrder.compactMap { modifier -> String? in
            guard binding.modifiers.contains(modifier) else { return nil }
            switch modifier {
            case "control": return "⌃"
            case "option": return "⌥"
            case "shift": return "⇧"
            case "command": return "⌘"
            default: return nil
            }
        }.joined()

        let key: String
        switch binding.key {
        case "upArrow": key = "↑"
        case "downArrow": key = "↓"
        case "leftArrow": key = "←"
        case "rightArrow": key = "→"
        case "slash": key = "/"
        case "comma": key = ","
        case "period": key = "."
        case "space": key = "Space"
        case "tab": key = "Tab"
        default: key = binding.key.uppercased()
        }

        return modifiers + key
    }
}
