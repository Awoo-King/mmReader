import Foundation

public final class ConfigStore {
    public let configURL: URL

    public init(baseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mmreader", isDirectory: true)) {
        self.configURL = baseURL.appendingPathComponent("config.json")
    }

    public func load() -> ReaderConfig {
        let fm = FileManager.default
        try? fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard fm.fileExists(atPath: configURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(ReaderConfig.self, from: data)
        } catch {
            save(.default)
            return .default
        }
    }

    public func save(_ config: ReaderConfig) {
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            return
        }
    }
}
