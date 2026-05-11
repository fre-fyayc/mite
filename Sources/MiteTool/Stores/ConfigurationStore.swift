import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var accountSubdomain: String = ""

    private let defaults: UserDefaults
    private let keychain: KeychainStoring

    private let accountKey = "mite.accountSubdomain"
    private let keychainService = "MiteTool.API"
    private let keychainAccount = "defaultUser"

    init(defaults: UserDefaults = .standard, keychain: KeychainStoring = KeychainService()) {
        self.defaults = defaults
        self.keychain = keychain
        self.accountSubdomain = defaults.string(forKey: accountKey) ?? ""
    }

    func save(accountSubdomain: String, apiKey: String) throws {
        defaults.set(accountSubdomain, forKey: accountKey)
        self.accountSubdomain = accountSubdomain
        try keychain.save(apiKey, service: keychainService, account: keychainAccount)
    }

    func currentConfiguration() throws -> MiteConfiguration? {
        guard let apiKey = try keychain.read(service: keychainService, account: keychainAccount),
              !accountSubdomain.isEmpty
        else {
            return nil
        }
        return MiteConfiguration(accountSubdomain: accountSubdomain, apiKey: apiKey)
    }
}
