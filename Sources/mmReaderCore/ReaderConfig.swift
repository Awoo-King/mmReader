import Foundation

public struct ReaderConfig: Codable, Equatable, Sendable {
    public var fontSize: Double
    public var bgAlpha: Double
    public var textAlpha: Double
    public var textColorHex: String
    public var linesPerPage: Int
    public var windowX: Double
    public var windowY: Double
    public var windowWidth: Double
    public var windowHeight: Double
    public var isPinned: Bool
    public var isFullscreen: Bool
    public var lastFilePath: String?
    public var lastPageIndex: Int
    public var lastAnchor: Int?
    public var isToolbarVisible: Bool
    public var shellMode: ReaderShellMode
    public var closeBehavior: ReaderCloseBehavior
    public var shortcuts: ReaderShortcutBindings

    public static let `default` = ReaderConfig(
        fontSize: 18,
        bgAlpha: 0.85,
        textAlpha: 1.0,
        textColorHex: "#000000",
        linesPerPage: 30,
        windowX: 120,
        windowY: 120,
        windowWidth: 680,
        windowHeight: 840,
        isPinned: false,
        isFullscreen: false,
        lastFilePath: nil,
        lastPageIndex: 0,
        lastAnchor: nil,
        isToolbarVisible: true,
        shellMode: .dockAndStatusItem,
        closeBehavior: .hideWindow,
        shortcuts: .default
    )
}
