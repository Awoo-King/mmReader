import Foundation

public struct ReaderShortcutBindings: Codable, Equatable, Sendable {
    public struct Key: Codable, Equatable, Sendable {
        public var key: String
        public var modifiers: [String]

        public init(key: String, modifiers: [String] = []) {
            self.key = key
            self.modifiers = modifiers
        }
    }

    public var previousPage: Key
    public var nextPage: Key
    public var toggleToolbar: Key
    public var openFile: Key
    public var closeWindow: Key
    public var toggleMainWindow: Key
    public var toggleControls: Key
    public var togglePin: Key
    public var hideToolbar: Key

    public static let `default` = ReaderShortcutBindings(
        previousPage: Key(key: "upArrow"),
        nextPage: Key(key: "downArrow"),
        toggleToolbar: Key(key: "b", modifiers: ["command"]),
        openFile: Key(key: "o", modifiers: ["command"]),
        closeWindow: Key(key: "w", modifiers: ["command"]),
        toggleMainWindow: Key(key: "m", modifiers: ["command"]),
        toggleControls: Key(key: ",", modifiers: ["command"]),
        togglePin: Key(key: "p", modifiers: ["command"]),
        hideToolbar: Key(key: "h", modifiers: ["command", "shift"])
    )
}
