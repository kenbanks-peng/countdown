import Foundation

/// Reads the supported configuration fields once. This is not a general TOML parser.
struct CountdownConfigurationFile {
    private let url: URL
    private let firstValues: [String: String]
    private let sectionValues: [String: [String: String]]

    init?(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let directory: URL
        if let configHome = environment["XDG_CONFIG_HOME"], !configHome.isEmpty {
            directory = URL(fileURLWithPath: configHome, isDirectory: true)
        } else {
            directory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        url = directory.appendingPathComponent("countdown", isDirectory: true)
            .appendingPathComponent("config.toml", isDirectory: false)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var firstValues: [String: String] = [:]
        var sectionValues: [String: [String: String]] = [:]
        var section = ""
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let header = trimmedLine.split(separator: "#", maxSplits: 1).first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            if header.hasPrefix("["), header.hasSuffix("]") {
                section = String(header.dropFirst().dropLast())
                continue
            }
            guard !trimmedLine.hasPrefix("#"), let equals = trimmedLine.firstIndex(of: "=") else { continue }
            let key = trimmedLine[..<equals].trimmingCharacters(in: .whitespaces)
            let value = trimmedLine[trimmedLine.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            // Preserve first-match behavior, including duplicate keys and section headers.
            if firstValues[key] == nil { firstValues[key] = value }
            if sectionValues[section]?[key] == nil { sectionValues[section, default: [:]][key] = value }
        }
        self.firstValues = firstValues
        self.sectionValues = sectionValues
    }

    func soundURL(for key: String) -> URL? {
        guard let value = firstValues[key], value.count >= 2,
              value.first == "\"", value.last == "\"" else { return nil }
        return URL(fileURLWithPath: String(value.dropFirst().dropLast()), relativeTo: url.deletingLastPathComponent())
    }

    func doubleValue(for key: String) -> Double? {
        guard let value = sectionValues[""]?[key] else { return nil }
        return Double(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }

    func intValue(for key: String, section: String? = nil) -> Int? {
        let value: String?
        if let section {
            value = sectionValues[section]?[key]
        } else {
            value = firstValues[key]
        }
        guard let value else { return nil }
        return Int(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }
}
