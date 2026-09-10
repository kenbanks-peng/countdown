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
        var arrayLine: String?
        for line in contents.split(whereSeparator: \.isNewline) {
            var trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let uncommented = trimmedLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first?.trimmingCharacters(in: .whitespaces) ?? ""
            if let pending = arrayLine {
                // An assignment or section header ends an unterminated array.
                if !uncommented.contains("="), !uncommented.hasPrefix("[") {
                    trimmedLine = pending + " " + uncommented
                    if !uncommented.contains("]") {
                        arrayLine = trimmedLine
                        continue
                    }
                } else if let equals = pending.firstIndex(of: "=") {
                    let key = pending[..<equals].trimmingCharacters(in: .whitespaces)
                    if sectionValues[section]?[key] == nil { sectionValues[section, default: [:]][key] = "invalid" }
                }
                arrayLine = nil
            } else if let equals = uncommented.firstIndex(of: "="),
                      uncommented[uncommented.index(after: equals)...].trimmingCharacters(in: .whitespaces).hasPrefix("["),
                      !uncommented.contains("]") {
                arrayLine = uncommented
                continue
            }
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

    func intArrayValue(for key: String, section: String) -> [Int]? {
        guard let raw = sectionValues[section]?[key] else { return nil }
        let value = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard value.hasPrefix("["), value.hasSuffix("]") else { return nil }
        let body = value.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        if body.isEmpty { return [] }
        var elements = body.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if elements.last == "" { elements.removeLast() } // TOML permits a trailing comma.
        let integers = elements.compactMap(Int.init)
        return integers.count == elements.count ? integers : nil
    }

    func intValue(for key: String, section: String) -> Int? {
        guard let value = sectionValues[section]?[key] else { return nil }
        return Int(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }
}
