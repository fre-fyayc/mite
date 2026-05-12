import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var accountSubdomain: String = ""
    @Published var timeEntryIntervalMinutes: Int
    @Published var wholeDayHours: Double

    private let defaults: UserDefaults
    private let keychain: KeychainStoring

    private let accountKey = "mite.accountSubdomain"
    private let timeEntryIntervalKey = "mite.timeEntryIntervalMinutes"
    private let wholeDayHoursKey = "mite.wholeDayHours"
    private let keychainService = "MiteTool.API"
    private let keychainAccount = "defaultUser"

    static let allowedIntervals: [Int] = [1, 5, 15, 30, 60]
    static let defaultIntervalMinutes = 15
    static let defaultWholeDayHours = 8.0
    static let wholeDayHoursRange: ClosedRange<Double> = 0.5...24.0

    init(defaults: UserDefaults = .standard, keychain: KeychainStoring = KeychainService()) {
        self.defaults = defaults
        self.keychain = keychain
        self.accountSubdomain = defaults.string(forKey: accountKey) ?? ""
        let storedInterval = defaults.object(forKey: timeEntryIntervalKey) as? Int
        self.timeEntryIntervalMinutes = Self.sanitizedInterval(storedInterval)

        let storedWholeDayHours = defaults.object(forKey: wholeDayHoursKey) as? Double
        self.wholeDayHours = Self.sanitizedWholeDayHours(storedWholeDayHours)
    }

    func save(accountSubdomain: String, apiKey: String) throws {
        defaults.set(accountSubdomain, forKey: accountKey)
        self.accountSubdomain = accountSubdomain
        try keychain.save(apiKey, service: keychainService, account: keychainAccount)
    }

    func saveTimeEntryPreferences(intervalMinutes: Int, wholeDayHours: Double) {
        let normalizedInterval = Self.sanitizedInterval(intervalMinutes)
        let normalizedWholeDayHours = Self.sanitizedWholeDayHours(wholeDayHours)

        defaults.set(normalizedInterval, forKey: timeEntryIntervalKey)
        defaults.set(normalizedWholeDayHours, forKey: wholeDayHoursKey)
        self.timeEntryIntervalMinutes = normalizedInterval
        self.wholeDayHours = normalizedWholeDayHours
    }

    var wholeDayMinutes: Int {
        max(1, Int((wholeDayHours * 60).rounded()))
    }

    func currentConfiguration() throws -> MiteConfiguration? {
        guard let apiKey = try keychain.read(service: keychainService, account: keychainAccount),
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
}
