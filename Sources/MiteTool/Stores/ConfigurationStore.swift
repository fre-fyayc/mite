import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var accountSubdomain: String = ""
    @Published var timeEntryIntervalMinutes: Int
    @Published var wholeDayHours: Double
    @Published var selectionDisplayMode: SelectionDisplayMode
    @Published var favoriteProjectIDs: Set<Int>
    @Published var favoriteServiceIDs: Set<Int>

    private let defaults: UserDefaults
    private let keychain: KeychainStoring
    private var cachedAPIKey: String?

    private let accountKey = "mite.accountSubdomain"
    private let timeEntryIntervalKey = "mite.timeEntryIntervalMinutes"
    private let wholeDayHoursKey = "mite.wholeDayHours"
    private let selectionDisplayModeKey = "mite.selectionDisplayMode"
    private let favoriteProjectIDsKey = "mite.favoriteProjectIDs"
    private let favoriteServiceIDsKey = "mite.favoriteServiceIDs"
    private let keychainService = "MiteTool.API"
    private let keychainAccount = "defaultUser"

    static let allowedIntervals: [Int] = [1, 5, 15, 30, 60]
    static let defaultIntervalMinutes = 15
    static let defaultWholeDayHours = 8.0
    static let defaultSelectionDisplayMode = SelectionDisplayMode.allEntries
    static let wholeDayHoursRange: ClosedRange<Double> = 0.5...24.0

    init(defaults: UserDefaults = .standard, keychain: KeychainStoring = KeychainService()) {
        self.defaults = defaults
        self.keychain = keychain
        self.accountSubdomain = defaults.string(forKey: accountKey) ?? ""
        let storedInterval = defaults.object(forKey: timeEntryIntervalKey) as? Int
        self.timeEntryIntervalMinutes = Self.sanitizedInterval(storedInterval)

        let storedWholeDayHours = defaults.object(forKey: wholeDayHoursKey) as? Double
        self.wholeDayHours = Self.sanitizedWholeDayHours(storedWholeDayHours)
        let storedModeRaw = defaults.string(forKey: selectionDisplayModeKey)
        self.selectionDisplayMode = Self.sanitizedSelectionDisplayMode(storedModeRaw)
        self.favoriteProjectIDs = Set(defaults.array(forKey: favoriteProjectIDsKey) as? [Int] ?? [])
        self.favoriteServiceIDs = Set(defaults.array(forKey: favoriteServiceIDsKey) as? [Int] ?? [])
    }

    func save(accountSubdomain: String, apiKey: String) throws {
        defaults.set(accountSubdomain, forKey: accountKey)
        self.accountSubdomain = accountSubdomain
        try keychain.save(apiKey, service: keychainService, account: keychainAccount)
        cachedAPIKey = apiKey
    }

    func saveTimeEntryPreferences(intervalMinutes: Int, wholeDayHours: Double) {
        let normalizedInterval = Self.sanitizedInterval(intervalMinutes)
        let normalizedWholeDayHours = Self.sanitizedWholeDayHours(wholeDayHours)

        defaults.set(normalizedInterval, forKey: timeEntryIntervalKey)
        defaults.set(normalizedWholeDayHours, forKey: wholeDayHoursKey)
        self.timeEntryIntervalMinutes = normalizedInterval
        self.wholeDayHours = normalizedWholeDayHours
    }

    func saveSelectionPreferences(mode: SelectionDisplayMode) {
        defaults.set(mode.rawValue, forKey: selectionDisplayModeKey)
        selectionDisplayMode = mode
    }

    func setProjectFavorite(_ projectID: Int, isFavorite: Bool) {
        var updatedFavorites = favoriteProjectIDs
        if isFavorite {
            updatedFavorites.insert(projectID)
        } else {
            updatedFavorites.remove(projectID)
        }
        favoriteProjectIDs = updatedFavorites
        defaults.set(Array(updatedFavorites).sorted(), forKey: favoriteProjectIDsKey)
    }

    func setServiceFavorite(_ serviceID: Int, isFavorite: Bool) {
        var updatedFavorites = favoriteServiceIDs
        if isFavorite {
            updatedFavorites.insert(serviceID)
        } else {
            updatedFavorites.remove(serviceID)
        }
        favoriteServiceIDs = updatedFavorites
        defaults.set(Array(updatedFavorites).sorted(), forKey: favoriteServiceIDsKey)
    }

    func isFavoriteProject(_ projectID: Int) -> Bool {
        favoriteProjectIDs.contains(projectID)
    }

    func isFavoriteService(_ serviceID: Int) -> Bool {
        favoriteServiceIDs.contains(serviceID)
    }

    var wholeDayMinutes: Int {
        max(1, Int((wholeDayHours * 60).rounded()))
    }

    func currentConfiguration() throws -> MiteConfiguration? {
        let apiKey: String?
        if let cachedAPIKey, !cachedAPIKey.isEmpty {
            apiKey = cachedAPIKey
        } else {
            let loadedAPIKey = try keychain.read(service: keychainService, account: keychainAccount)
            if let loadedAPIKey, !loadedAPIKey.isEmpty {
                cachedAPIKey = loadedAPIKey
            }
            apiKey = loadedAPIKey
        }

        guard let apiKey,
              !accountSubdomain.isEmpty
        else {
            return nil
        }
        return MiteConfiguration(accountSubdomain: accountSubdomain, apiKey: apiKey)
    }

    private static func sanitizedInterval(_ value: Int?) -> Int {
        guard let value else { return defaultIntervalMinutes }
        return allowedIntervals.contains(value) ? value : defaultIntervalMinutes
    }

    private static func sanitizedWholeDayHours(_ value: Double?) -> Double {
        guard let value else { return defaultWholeDayHours }
        return min(max(value, wholeDayHoursRange.lowerBound), wholeDayHoursRange.upperBound)
    }

    private static func sanitizedSelectionDisplayMode(_ rawValue: String?) -> SelectionDisplayMode {
        guard let rawValue, let mode = SelectionDisplayMode(rawValue: rawValue) else {
            return defaultSelectionDisplayMode
        }
        return mode
    }
}
