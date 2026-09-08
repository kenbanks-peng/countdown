import Foundation

/// Atomic JSON storage. Missing, invalid, or unwritable files do not stop a countdown.
struct JSONStateFile<Value: Codable> {
    let fileManager: FileManager
    let directory: URL
    let name: String

    private var url: URL { directory.appendingPathComponent(name, isDirectory: false) }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            // Keep the in-memory value; a failed write does not promise persistence.
        }
    }

    func remove() {
        try? fileManager.removeItem(at: url)
    }
}
