import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isBusy = false
    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published var selectedEntriesDate = Calendar.current.startOfDay(for: .now)
    @Published var todayEntries: [MiteTimeEntry] = []
    @Published var isLoadingTodayEntries = false
    @Published var entriesErrorMessage: String?

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
        defer {
            isBusy = false
        }

        do {
            guard let config = try configStore.currentConfiguration() else {
                throw AppError.missingConfiguration
            }
            try await apiClient.createTimeEntry(draft, config: config)
            infoMessage = "Time entry saved."
            await loadEntries(for: selectedEntriesDate, showBannerOnError: false)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadTodayEntries(showBannerOnError: Bool = false) async {
        await loadEntries(for: Calendar.current.startOfDay(for: .now), showBannerOnError: showBannerOnError)
    }

    func loadEntries(for date: Date, showBannerOnError: Bool = false) async {
        isLoadingTodayEntries = true
        entriesErrorMessage = nil
        defer { isLoadingTodayEntries = false }

        do {
            guard let config = try configStore.currentConfiguration() else {
                todayEntries = []
                return
            }
            selectedEntriesDate = Calendar.current.startOfDay(for: date)
            todayEntries = try await apiClient.fetchTimeEntries(for: selectedEntriesDate, config: config)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            entriesErrorMessage = message
            if showBannerOnError {
                errorMessage = message
            }
        }
    }

    func projectName(for entry: MiteTimeEntry) -> String {
        if let projectName = entry.projectName, !projectName.isEmpty {
            return projectName
        }
        if let projectID = entry.projectID {
            return catalogStore.projects.first(where: { $0.id == projectID })?.name ?? "Project \(projectID)"
        }
        return "Unknown project"
    }

    func serviceName(for entry: MiteTimeEntry) -> String {
        if let serviceName = entry.serviceName, !serviceName.isEmpty {
            return serviceName
        }
        if let serviceID = entry.serviceID {
            return catalogStore.services.first(where: { $0.id == serviceID })?.name ?? "Service \(serviceID)"
        }
        return "Unknown service"
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
