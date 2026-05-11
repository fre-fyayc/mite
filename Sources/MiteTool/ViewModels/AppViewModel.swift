import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isBusy = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?

    let configStore: ConfigurationStore
    let presetStore: PresetStore
    let catalogStore: CatalogStore

    private let apiClient: MiteAPIClienting

    init(
        configStore: ConfigurationStore = ConfigurationStore(),
        presetStore: PresetStore = PresetStore(),
        catalogStore: CatalogStore = CatalogStore(),
        apiClient: MiteAPIClienting = MiteAPIClient()
    ) {
        self.configStore = configStore
        self.presetStore = presetStore
        self.catalogStore = catalogStore
        self.apiClient = apiClient
        self.presetStore.load()
        self.catalogStore.load()
    }

    func saveConfiguration(accountSubdomain: String, apiKey: String) async {
        clearMessages()
        do {
            try configStore.save(
                accountSubdomain: accountSubdomain.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            infoMessage = "Configuration saved."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func testConnection() async {
        clearMessages()
        isBusy = true
        defer { isBusy = false }

        do {
            guard let config = try configStore.currentConfiguration() else {
                throw AppError.missingConfiguration
            }
            try await apiClient.testConnection(config: config)
            infoMessage = "Connection successful."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshCatalog() async {
        clearMessages()
        isBusy = true
        defer { isBusy = false }

        do {
            guard let config = try configStore.currentConfiguration() else {
                throw AppError.missingConfiguration
            }
            let loadedProjects = try await apiClient.fetchProjects(config: config)
            let loadedServices = try await apiClient.fetchServices(config: config)
            try catalogStore.update(projects: loadedProjects, services: loadedServices)
            infoMessage = "Projects and services refreshed."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func submitEntry(_ draft: TimeEntryDraft) async {
        clearMessages()
        isBusy = true
        defer { isBusy = false }

        do {
            guard let config = try configStore.currentConfiguration() else {
                throw AppError.missingConfiguration
            }
            try await apiClient.createTimeEntry(draft, config: config)
            infoMessage = "Time entry saved."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addPreset(_ preset: MitePreset) {
        clearMessages()
        do {
            try presetStore.add(preset)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func updatePreset(_ preset: MitePreset) {
        clearMessages()
        do {
            try presetStore.update(preset)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deletePreset(id: UUID) {
        clearMessages()
        do {
            try presetStore.remove(id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func movePresets(fromOffsets: IndexSet, toOffset: Int) {
        clearMessages()
        do {
            try presetStore.move(fromOffsets: fromOffsets, toOffset: toOffset)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearMessages() {
        infoMessage = nil
        errorMessage = nil
    }
}
