import Foundation
import Testing
@testable import MiteTool

private final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Missing URL request handler")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MemoryFileStorage: FileStoring, @unchecked Sendable {
    private var values: [String: Data] = [:]

    func load<T>(_ type: T.Type, from fileName: String) throws -> T? where T : Decodable {
        guard let data = values[fileName] else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func save<T>(_ value: T, to fileName: String) throws where T : Encodable {
        values[fileName] = try JSONEncoder().encode(value)
    }
}

private final class KeychainStoreMock: KeychainStoring, @unchecked Sendable {
    private var values: [String: String] = [:]

    func save(_ value: String, service: String, account: String) throws {
        values["\(service)|\(account)"] = value
    }

    func read(service: String, account: String) throws -> String? {
        values["\(service)|\(account)"]
    }
}

@Suite(.serialized)
struct MiteToolTests {
    @Test
    func createTimeEntrySendsExpectedPayload() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: config)
        let client = MiteAPIClient(session: session, userAgent: "Tests")

        URLProtocolMock.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://demo.mite.de/time_entries.json")
            #expect(request.value(forHTTPHeaderField: "X-MiteApiKey") == "secret")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(requestBodyData(from: request))
            let bodyString = String(decoding: body, as: UTF8.self)
            #expect(bodyString.contains("\"project_id\":1"))
            #expect(bodyString.contains("\"service_id\":2"))
            #expect(bodyString.contains("\"minutes\":45"))
            #expect(bodyString.contains("\"date_at\":\"2026-05-11\""))
            #expect(bodyString.contains("\"note\":\"Deep work\""))

            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        var draft = TimeEntryDraft.empty()
        draft.projectID = 1
        draft.serviceID = 2
        draft.note = "Deep work"
        draft.minutes = 45
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        draft.date = try #require(formatter.date(from: "2026-05-11"))

        let miteConfig = MiteConfiguration(accountSubdomain: "demo", apiKey: "secret")
        try await client.createTimeEntry(draft, config: miteConfig)
    }

    @Test @MainActor
    func presetStorePersistsEntries() throws {
        let storage = MemoryFileStorage()
        let store = PresetStore(storage: storage)
        store.load()
        #expect(store.presets.isEmpty)

        try store.add(
            MitePreset(
                id: UUID(),
                title: "Daily standup",
                projectID: 1,
                serviceID: 2,
                note: "Standup prep",
                defaultMinutes: 15
            )
        )

        let reloadedStore = PresetStore(storage: storage)
        reloadedStore.load()
        #expect(reloadedStore.presets.count == 1)
        #expect(reloadedStore.presets[0].title == "Daily standup")
    }

    @Test
    func fetchTimeEntriesFiltersByCurrentUser() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: config)
        let client = MiteAPIClient(session: session, userAgent: "Tests")

        URLProtocolMock.requestCount = 0
        URLProtocolMock.requestHandler = { request in
            URLProtocolMock.requestCount += 1
            let url = try #require(request.url)
            #expect(request.httpMethod == "GET")

            if URLProtocolMock.requestCount == 1 {
                #expect(url.absoluteString == "https://demo.mite.de/myself.json")
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let payload = #"{"user":{"id":42,"name":"Tester"}}"#.data(using: .utf8) ?? Data()
                return (response, payload)
            }

            #expect(url.query?.contains("at=2026-05-11") == true)
            #expect(url.query?.contains("user_id=42") == true)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = #"[{"time_entry":{"id":99,"project_id":1,"service_id":2,"project_name":"Project","service_name":"Service","note":"Focused work","minutes":30,"date_at":"2026-05-11","created_at":"2026-05-11T10:00:00Z"}}]"#.data(using: .utf8) ?? Data()
            return (response, payload)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = try #require(formatter.date(from: "2026-05-11"))
        let miteConfig = MiteConfiguration(accountSubdomain: "demo", apiKey: "secret")

        let entries = try await client.fetchTimeEntries(for: date, config: miteConfig)
        #expect(URLProtocolMock.requestCount == 2)
        #expect(entries.count == 1)
        #expect(entries[0].id == 99)
    }

    @Test @MainActor
    func configurationStoreUsesDefaultTimeEntryPreferences() {
        let defaults = UserDefaults(suiteName: "MiteToolTests.ConfigurationDefaults")!
        defaults.removePersistentDomain(forName: "MiteToolTests.ConfigurationDefaults")
        let keychain = KeychainStoreMock()
        let store = ConfigurationStore(defaults: defaults, keychain: keychain)

        #expect(store.timeEntryIntervalMinutes == 15)
        #expect(store.wholeDayHours == 8.0)
        #expect(store.wholeDayMinutes == 480)
    }

    @Test @MainActor
    func configurationStorePersistsTimeEntryPreferences() {
        let defaults = UserDefaults(suiteName: "MiteToolTests.ConfigurationPersistence")!
        defaults.removePersistentDomain(forName: "MiteToolTests.ConfigurationPersistence")
        let keychain = KeychainStoreMock()

        let store = ConfigurationStore(defaults: defaults, keychain: keychain)
        store.saveTimeEntryPreferences(intervalMinutes: 30, wholeDayHours: 6.5)

        let reloadedStore = ConfigurationStore(defaults: defaults, keychain: keychain)
        #expect(reloadedStore.timeEntryIntervalMinutes == 30)
        #expect(reloadedStore.wholeDayHours == 6.5)
        #expect(reloadedStore.wholeDayMinutes == 390)
    }
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let readCount = stream.read(buffer, maxLength: bufferSize)
        if readCount < 0 {
            return nil
        }
        if readCount == 0 {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}
