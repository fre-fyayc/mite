import Foundation

protocol FileStoring {
    func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T?
    func save<T: Encodable>(_ value: T, to fileName: String) throws
}

struct FileStorage: FileStoring {
    private let directoryURL: URL

    init(folderName: String = "MiteTool") {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T? {
        let url = directoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, to fileName: String) throws {
        let url = directoryURL.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
