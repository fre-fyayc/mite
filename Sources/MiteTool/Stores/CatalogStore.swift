import Foundation

struct CatalogCache: Codable {
    var projects: [MiteProject]
    var services: [MiteService]
}

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var projects: [MiteProject] = []
    @Published private(set) var services: [MiteService] = []

    private let storage: FileStoring
    private let fileName = "catalog-cache.json"

    init(storage: FileStoring = FileStorage()) {
        self.storage = storage
    }

    func load() {
        do {
            let cache = try storage.load(CatalogCache.self, from: fileName)
            projects = cache?.projects ?? []
            services = cache?.services ?? []
        } catch {
            projects = []
            services = []
        }
    }

    func update(projects: [MiteProject], services: [MiteService]) throws {
        self.projects = projects
        self.services = services
        do {
            try storage.save(CatalogCache(projects: projects, services: services), to: fileName)
        } catch {
            throw AppError.persistence(message: "Could not save cached projects/services.")
        }
    }
}
