import Foundation

struct FavoritePair: Codable, Equatable {
    var label: String
    var projectId: Int
    var serviceId: Int
}

struct AppConfig: Codable, Equatable {
    var account: String
    var pairs: [FavoritePair]

    static let empty = AppConfig(account: "", pairs: [])

    init(account: String, pairs: [FavoritePair]) {
        self.account = account
        self.pairs = pairs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        pairs = try container.decodeIfPresent([FavoritePair].self, forKey: .pairs) ?? []
    }
}

enum ConfigError: LocalizedError {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case let .unreadable(detail):
            return detail
        }
    }

    static func describe(_ error: Error) -> String {
        let detail: String
        if let decoding = error as? DecodingError {
            switch decoding {
            case let .keyNotFound(key, context):
                detail = "Missing \(codingPath(context, extra: key.stringValue))."
            case let .typeMismatch(_, context):
                detail = "Wrong type of value at \(codingPath(context))."
            case let .valueNotFound(_, context):
                detail = "Missing value at \(codingPath(context))."
            case let .dataCorrupted(context):
                detail = context.debugDescription
            @unknown default:
                detail = decoding.localizedDescription
            }
        } else {
            detail = error.localizedDescription
        }
        let clipped = detail.count > 180 ? String(detail.prefix(180)) + "…" : detail
        return "Could not read \(FavoritesStore.displayPath). \(clipped)"
    }

    private static func codingPath(_ context: DecodingError.Context, extra: String? = nil) -> String {
        var parts = context.codingPath.map(\.stringValue)
        if let extra {
            parts.append(extra)
        }
        return parts.isEmpty ? "the file" : parts.joined(separator: ".")
    }
}

enum FavoritesStore {
    private static let decoder = JSONDecoder()

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mite-menu/config.json")
    }

    static var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = fileURL.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func normalizeAccount(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let withScheme = value.contains("://") ? value : "https://\(value)"
        if let host = URL(string: withScheme)?.host, !host.isEmpty {
            value = host
        }
        let suffix = ".mite.de"
        if value.lowercased().hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
        }
        value = value.split(separator: ".").first.map(String.init) ?? value
        value = value.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard !value.isEmpty, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return value
    }

    static func load() throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        do {
            let data = try Data(contentsOf: fileURL)
            if data.isEmpty { return .empty }
            return try decoder.decode(AppConfig.self, from: data)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.unreadable(ConfigError.describe(error))
        }
    }

    static func save(_ config: AppConfig) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let object: [String: Any] = [
            "account": config.account,
            "pairs": config.pairs.map { pair -> [String: Any] in
                [
                    "label": pair.label,
                    "projectId": pair.projectId,
                    "serviceId": pair.serviceId,
                ]
            },
        ]
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if data.last != 0x0A {
            data.append(0x0A)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    static func setAccount(_ account: String) throws {
        var config = try load()
        config.account = account
        try save(config)
    }

    static func addPair(_ pair: FavoritePair) throws {
        var config = try load()
        config.pairs.append(pair)
        try save(config)
    }

    static func ensureFile() throws {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try save(.empty)
        }
    }

    static func suggestedLabel(project: MiteProject, service: MiteService) -> String {
        let customer = project.customerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prefix = customer.isEmpty ? project.name : customer
        return "\(prefix) — \(service.name)"
    }
}
