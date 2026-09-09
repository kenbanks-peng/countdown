import Foundation

/// Reads the supported configuration fields once. This is not a general TOML parser.
struct CountdownConfigurationFile {
    private let url: URL
    private let sectionValues: [String: [String: String]]

    init(
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
        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

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
            // The first value in each section wins.
            if sectionValues[section]?[key] == nil { sectionValues[section, default: [:]][key] = value }
        }
        self.sectionValues = sectionValues
    }

    func soundURL(for key: String, defaultName: String) -> URL {
        var path = defaultName
        if let value = sectionValues["notifications"]?[key], value.first == "\"",
           let end = value.dropFirst().firstIndex(of: "\"") {
            let suffix = value[value.index(after: end)...].trimmingCharacters(in: .whitespaces)
            let candidate = String(value[value.index(after: value.startIndex)..<end])
            if !candidate.isEmpty && (suffix.isEmpty || suffix.hasPrefix("#")) {
                path = candidate
            }
        }
        return URL(fileURLWithPath: path, relativeTo: url.deletingLastPathComponent())
    }

    func stringValue(for key: String, section: String) -> String? {
        guard let value = sectionValues[section]?[key], value.first == "\"",
              let end = value.dropFirst().firstIndex(of: "\"") else { return nil }
        let suffix = value[value.index(after: end)...].trimmingCharacters(in: .whitespaces)
        guard suffix.isEmpty || suffix.hasPrefix("#") else { return nil }
        return String(value[value.index(after: value.startIndex)..<end])
    }

    func boolValue(for key: String, section: String = "notifications") -> Bool? {
        guard let value = sectionValues[section]?[key] else { return nil }
        switch value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    func doubleValue(for key: String, section: String = "") -> Double? {
        guard let value = sectionValues[section]?[key] else { return nil }
        return Double(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }

    func intValue(for key: String, section: String) -> Int? {
        guard let value = sectionValues[section]?[key] else { return nil }
        return Int(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }
}
