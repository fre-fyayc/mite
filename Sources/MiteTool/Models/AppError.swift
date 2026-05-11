import Foundation

enum AppError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case decodingFailed
    case api(message: String)
    case unauthorized
    case forbidden
    case validation(message: String)
    case persistence(message: String)
    case keychain(message: String)
    case network(message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Please configure account subdomain and API key in Settings."
        case .invalidURL:
            return "The MITE account URL is invalid."
        case .decodingFailed:
            return "Could not decode server response."
        case .api(let message):
            return message
        case .unauthorized:
            return "Access denied. Please check your API key."
        case .forbidden:
            return "Your user cannot perform this action."
        case .validation(let message):
            return message
        case .persistence(let message):
            return message
        case .keychain(let message):
            return message
        case .network(let message):
            return message
        }
    }
}
