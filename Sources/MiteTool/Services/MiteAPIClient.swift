import Foundation

protocol MiteAPIClienting: Sendable {
    func testConnection(config: MiteConfiguration) async throws
    func fetchProjects(config: MiteConfiguration) async throws -> [MiteProject]
    func fetchServices(config: MiteConfiguration) async throws -> [MiteService]
    func createTimeEntry(_ draft: TimeEntryDraft, config: MiteConfiguration) async throws
}

struct MiteConfiguration: Codable, Hashable {
    var accountSubdomain: String
    var apiKey: String
}

struct MiteAPIClient: MiteAPIClienting, Sendable {
    private let session: URLSession
    private let userAgent: String

    init(session: URLSession = .shared, userAgent: String = "MiteTool/1.0 (macOS)") {
        self.session = session
        self.userAgent = userAgent
    }

    func testConnection(config: MiteConfiguration) async throws {
        _ = try await sendJSONRequest(
            config: config,
            path: "/myself.json",
            method: "GET",
            body: Optional<MiteCreateTimeEntryBody>.none
        ) as MiteMyselfEnvelope
    }

    func fetchProjects(config: MiteConfiguration) async throws -> [MiteProject] {
        let envelopes: [MiteProjectEnvelope] = try await sendJSONRequest(
            config: config,
            path: "/projects.json",
            method: "GET",
            body: Optional<MiteCreateTimeEntryBody>.none
        )
        return envelopes.map { MiteProject(id: $0.project.id, name: $0.project.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fetchServices(config: MiteConfiguration) async throws -> [MiteService] {
        let envelopes: [MiteServiceEnvelope] = try await sendJSONRequest(
            config: config,
            path: "/services.json",
            method: "GET",
            body: Optional<MiteCreateTimeEntryBody>.none
        )
        return envelopes.map { MiteService(id: $0.service.id, name: $0.service.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createTimeEntry(_ draft: TimeEntryDraft, config: MiteConfiguration) async throws {
        guard let projectID = draft.projectID, let serviceID = draft.serviceID else {
            throw AppError.validation(message: "Please select both project and service.")
        }
        guard draft.minutes > 0 else {
            throw AppError.validation(message: "Minutes must be greater than zero.")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let payload = MiteCreateTimeEntryBody(
            timeEntry: MiteCreateTimeEntryPayload(
                projectID: projectID,
                serviceID: serviceID,
                note: draft.note,
                minutes: draft.minutes,
                dateAt: dateFormatter.string(from: draft.date)
            )
        )

        _ = try await sendDataRequest(
            config: config,
            path: "/time_entries.json",
            method: "POST",
            body: payload
        )
    }

    private func sendJSONRequest<T: Decodable, Body: Encodable>(
        config: MiteConfiguration,
        path: String,
        method: String,
        body: Body?
    ) async throws -> T {
        let data = try await sendDataRequest(config: config, path: path, method: method, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.decodingFailed
        }
    }

    private func sendDataRequest<Body: Encodable>(
        config: MiteConfiguration,
        path: String,
        method: String,
        body: Body?
    ) async throws -> Data {
        guard !config.accountSubdomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppError.missingConfiguration
        }

        let host = "\(config.accountSubdomain).mite.de"
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        guard let url = components.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.apiKey, forHTTPHeaderField: "X-MiteApiKey")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.network(message: "Unexpected response.")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw mapAPIError(statusCode: httpResponse.statusCode, data: data)
            }
            return data
        } catch let appError as AppError {
            throw appError
        } catch {
            throw AppError.network(message: error.localizedDescription)
        }
    }

    private func mapAPIError(statusCode: Int, data: Data) -> AppError {
        if let decoded = try? JSONDecoder().decode(MiteAPIErrorPayload.self, from: data) {
            switch statusCode {
            case 401:
                return .unauthorized
            case 403, 404:
                return .forbidden
            case 422:
                return .validation(message: decoded.error)
            default:
                return .api(message: decoded.error)
            }
        }
        switch statusCode {
        case 401:
            return .unauthorized
        case 403, 404:
            return .forbidden
        case 422:
            return .validation(message: "The server rejected your data.")
        default:
            return .api(message: "Request failed with HTTP \(statusCode).")
        }
    }
}
