import Foundation

public enum ReaderShellMode: String, Codable, Equatable, Sendable {
    case dockOnly
    case statusItemOnly
    case dockAndStatusItem
}
