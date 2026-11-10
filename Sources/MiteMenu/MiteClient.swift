import Foundation

struct MiteProject: Decodable, Equatable {
    let id: Int
    let name: String
    let customerName: String?
}

struct MiteService: Decodable, Equatable {
    let id: Int
    let name: String
}

struct TrackerSnapshot: Equatable {
    let entryId: Int
    let since: Date
    /// Minutes stored on this entry before the current run. Finish adds the current run on top of this.
    let minutesAlready: Int
    let headline: String
    let note: String
}

struct TodayEntry: Equatable {
    let id: Int
    let minutes: Int
    let note: String
    let headline: String
    let locked: Bool
    var projectId: Int? = nil
    var serviceId: Int? = nil
}

enum MiteError: LocalizedError {
    case missingCredentials
    case invalidAccount
    case requestFailed(Int, String)
    case savedWithoutRounding(Int, String)
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "The API key could not be read from the Keychain. Open Connect, click Save connection, and choose Allow if macOS asks."
        case .invalidAccount:
            return "Enter the account subdomain, such as your-account from your-account.mite.de."
        case let .requestFailed(status, message):
            if !message.isEmpty { return message }
            if status == 401 || status == 403 {
                return "mite refused the API key. Check the account name and the key."
            }
            return "mite returned HTTP \(status)."
        case let .savedWithoutRounding(minutes, message):
            if message.isEmpty {
                return "The timer stopped, but mite did not save \(minutes) minutes."
            }
            return "The timer stopped, but mite did not save \(minutes) minutes. \(message)"
        case .unreadableResponse:
            return "mite returned a response the app could not read."
        }
    }
}

struct MiteClient {
    let account: String
    let apiKey: String

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static func make() throws -> MiteClient {
        let config = try FavoritesStore.load()
        guard let account = FavoritesStore.normalizeAccount(config.account) else {
            throw MiteError.invalidAccount
        }
        guard let apiKey = Keychain.load() else {
            throw MiteError.missingCredentials
        }
        return MiteClient(account: account, apiKey: apiKey)
    }

    func projects() async throws -> [MiteProject] {
        let data = try await request(method: "GET", path: "/projects.json")
        return try decode([ProjectBox].self, from: data).map(\.project)
    }

    func services() async throws -> [MiteService] {
        let data = try await request(method: "GET", path: "/services.json")
        return try decode([ServiceBox].self, from: data).map(\.service)
    }

    func currentTracker() async throws -> TrackerSnapshot? {
        let data = try await request(method: "GET", path: "/tracker.json")
        let envelope = try decode(TrackerEnvelope.self, from: data)
        guard let running = envelope.tracker.trackingTimeEntry else { return nil }
        let details = try? await timeEntry(id: running.id)
        let since = parseSince(running.since ?? details?.tracking?.since, minutes: running.minutes)
        let reported = details?.tracking?.minutes ?? running.minutes ?? 0
        return TrackerSnapshot(
            entryId: running.id,
            since: since,
            minutesAlready: minutesAlready(reported: reported, stored: details?.minutes, since: since),
            headline: headline(
                customer: details?.customerName,
                project: details?.projectName,
                service: details?.serviceName
            ),
            note: details?.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    func today() async throws -> [TodayEntry] {
        let data = try await request(method: "GET", path: "/daily.json")
        return try mapEntries(data)
    }

    func entries(on day: String) async throws -> [TodayEntry] {
        let data = try await request(method: "GET", path: "/time_entries.json?user_id=current&at=\(day)")
        return try mapEntries(data)
    }

    /// Writes an exact minute total onto one pair for one day. Does not start the tracker and does not round.
    func addSettledTime(projectId: Int, serviceId: Int, minutes: Int, note: String, day: String) async throws {
        _ = try await createTimeEntry(projectId: projectId, serviceId: serviceId, note: note, minutes: minutes, day: day)
    }

    /// Replaces the stored minutes on an entry. Does not round.
    func saveMinutes(entryId: Int, minutes: Int) async throws {
        try await updateMinutes(entryId: entryId, minutes: minutes)
    }

    func start(projectId: Int, serviceId: Int, note: String, headline: String) async throws -> TrackerSnapshot {
        let created = try await createTimeEntry(projectId: projectId, serviceId: serviceId, note: note)
        do {
            let since = try await startTracker(id: created.id)
            return TrackerSnapshot(
                entryId: created.id,
                since: since,
                minutesAlready: max(0, created.minutes ?? 0),
                headline: headline,
                note: note
            )
        } catch {
            try? await deleteTimeEntry(id: created.id)
            throw error
        }
    }

    func resume(_ entry: TodayEntry) async throws -> TrackerSnapshot {
        let since = try await startTracker(id: entry.id)
        return TrackerSnapshot(
            entryId: entry.id,
            since: since,
            minutesAlready: max(0, entry.minutes),
            headline: entry.headline,
            note: entry.note
        )
    }

    /// Stops the clock and leaves the minutes mite stored for this run.
    func pause(entryId: Int) async throws {
        _ = try await stopTracker(entryId: entryId)
    }

    /// Stops the clock and saves the next full block for the whole entry, including earlier runs.
    func finish(entryId: Int, minutesAlready: Int, since: Date, roundUpTo increment: Int) async throws {
        guard increment > 0 else {
            try await pause(entryId: entryId)
            return
        }
        let tracked = MinuteRounding.ceil(already: minutesAlready, since: since, increment: increment)
        let stopped = try await stopTracker(entryId: entryId)
        let minutes = max(tracked, MinuteRounding.ceil(minutes: stopped, increment: increment))
        guard minutes > 0 else { return }
        do {
            try await updateMinutes(entryId: entryId, minutes: minutes)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            throw MiteError.savedWithoutRounding(minutes, detail)
        }
    }

    private func mapEntries(_ data: Data) throws -> [TodayEntry] {
        let entries = try decode([TimeEntryBox].self, from: data).map(\.timeEntry)
        return entries.sorted { lhs, rhs in
            let left = parseISO(lhs.updatedAt) ?? .distantPast
            let right = parseISO(rhs.updatedAt) ?? .distantPast
            if left != right { return left > right }
            return lhs.id > rhs.id
        }.map { entry in
            TodayEntry(
                id: entry.id,
                minutes: max(0, entry.minutes ?? 0),
                note: entry.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                headline: headline(
                    customer: entry.customerName,
                    project: entry.projectName,
                    service: entry.serviceName
                ),
                locked: entry.locked ?? false,
                projectId: entry.projectId,
                serviceId: entry.serviceId
            )
        }
    }

    private func createTimeEntry(
        projectId: Int,
        serviceId: Int,
        note: String,
        minutes: Int = 0,
        day: String? = nil
    ) async throws -> TimeEntryBody {
        let payload = TimeEntryPayload(timeEntry: TimeEntryWrite(
            dateAt: day ?? Self.todayString(),
            minutes: minutes,
            note: note,
            projectId: projectId,
            serviceId: serviceId
        ))
        let body = try Self.encoder.encode(payload)
        let data = try await request(method: "POST", path: "/time_entries.json", body: body)
        return try decode(TimeEntryEnvelope.self, from: data).timeEntry
    }

    private func startTracker(id: Int) async throws -> Date {
        let data = try await request(method: "PATCH", path: "/tracker/\(id).json")
        if let envelope = try? Self.decoder.decode(TrackerEnvelope.self, from: data),
           let running = envelope.tracker.trackingTimeEntry {
            return parseSince(running.since, minutes: running.minutes)
        }
        return Date()
    }

    private func stopTracker(entryId: Int) async throws -> Int {
        let data = try await request(method: "DELETE", path: "/tracker/\(entryId).json")
        let envelope = try? Self.decoder.decode(TrackerEnvelope.self, from: data)
        return max(0, envelope?.tracker.stoppedTimeEntry?.minutes ?? 0)
    }

    /// Minutes saved before this run. mite's live total already includes the current run, so those whole minutes are removed.
    private func minutesAlready(reported: Int, stored: Int?, since: Date) -> Int {
        if let stored, stored < reported {
            return max(0, stored)
        }
        let elapsedMinutes = Int((max(0, Date().timeIntervalSince(since)) / 60).rounded(.down))
        return max(0, reported - elapsedMinutes)
    }

    private func updateMinutes(entryId: Int, minutes: Int) async throws {
        let payload = MinutesPayload(timeEntry: MinutesWrite(minutes: minutes))
        let body = try Self.encoder.encode(payload)
        _ = try await request(method: "PATCH", path: "/time_entries/\(entryId).json", body: body)
    }

    private func deleteTimeEntry(id: Int) async throws {
        _ = try await request(method: "DELETE", path: "/time_entries/\(id).json")
    }

    private func timeEntry(id: Int) async throws -> TimeEntryBody {
        let data = try await request(method: "GET", path: "/time_entries/\(id).json")
        return try decode(TimeEntryEnvelope.self, from: data).timeEntry
    }

    private func request(method: String, path: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "https://\(account).mite.de\(path)") else {
            throw MiteError.invalidAccount
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "X-MiteApiKey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("mite-menu/0.4 (macOS menu bar)", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw MiteError.requestFailed(0, error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw MiteError.unreadableResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw MiteError.requestFailed(http.statusCode, Self.apiMessage(from: data))
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw MiteError.unreadableResponse
        }
    }

    private static func apiMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
            let message = decoded.error.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { return message }
        }
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty, text.count < 300, !text.hasPrefix("<")
        else { return "" }
        return text
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func parseSince(_ value: String?, minutes: Int?) -> Date {
        if let date = parseISO(value) {
            return date
        }
        return Date().addingTimeInterval(-Double(minutes ?? 0) * 60)
    }

    private func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = try? Date(value, strategy: .iso8601) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func headline(customer: String?, project: String?, service: String?) -> String {
        let serviceName = nonEmpty(service) ?? ""
        if let customer = nonEmpty(customer) {
            return serviceName.isEmpty ? customer : "\(customer) — \(serviceName)"
        }
        if let project = nonEmpty(project) {
            return serviceName.isEmpty ? project : "\(project) — \(serviceName)"
        }
        return serviceName
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ProjectBox: Decodable {
    let project: MiteProject
}

private struct ServiceBox: Decodable {
    let service: MiteService
}

private struct APIErrorBody: Decodable {
    let error: String
}

private struct TrackerEnvelope: Decodable {
    struct Tracker: Decodable {
        struct Entry: Decodable {
            let id: Int
            let minutes: Int?
            let since: String?
        }

        let trackingTimeEntry: Entry?
        let stoppedTimeEntry: Entry?
    }

    let tracker: Tracker
}

private struct TimeEntryBox: Decodable {
    let timeEntry: TimeEntryBody
}

private struct TimeEntryEnvelope: Decodable {
    let timeEntry: TimeEntryBody
}

private struct TimeEntryBody: Decodable {
    struct Tracking: Decodable {
        let since: String?
        let minutes: Int?
    }

    let id: Int
    let minutes: Int?
    let note: String?
    let projectId: Int?
    let projectName: String?
    let customerName: String?
    let serviceId: Int?
    let serviceName: String?
    let locked: Bool?
    let updatedAt: String?
    let tracking: Tracking?
}

private struct TimeEntryPayload: Encodable {
    let timeEntry: TimeEntryWrite
}

private struct TimeEntryWrite: Encodable {
    let dateAt: String
    let minutes: Int
    let note: String
    let projectId: Int
    let serviceId: Int
}

private struct MinutesPayload: Encodable {
    let timeEntry: MinutesWrite
}

private struct MinutesWrite: Encodable {
    let minutes: Int
}
