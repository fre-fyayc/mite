import XCTest
import Foundation
@testable import MiteTool

private final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

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

final class MiteToolTests: XCTestCase {
    func testCreateTimeEntrySendsExpectedPayload() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: config)
        let client = MiteAPIClient(session: session, userAgent: "Tests")

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://demo.mite.de/time_entries.json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-MiteApiKey"), "secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(request.httpBody)
            let bodyString = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyString.contains("\"project_id\":1"))
            XCTAssertTrue(bodyString.contains("\"service_id\":2"))
            XCTAssertTrue(bodyString.contains("\"minutes\":45"))
            XCTAssertTrue(bodyString.contains("\"date_at\":\"2026-05-11\""))
            XCTAssertTrue(bodyString.contains("\"note\":\"Deep work\""))

            let url = try XCTUnwrap(request.url)
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
        draft.date = try XCTUnwrap(formatter.date(from: "2026-05-11"))

        let miteConfig = MiteConfiguration(accountSubdomain: "demo", apiKey: "secret")
        try await client.createTimeEntry(draft, config: miteConfig)
    }

    @MainActor
    func testPresetStorePersistsEntries() throws {
        let storage = MemoryFileStorage()
        let store = PresetStore(storage: storage)
        store.load()
        XCTAssertTrue(store.presets.isEmpty)

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
        XCTAssertEqual(reloadedStore.presets.count, 1)
        XCTAssertEqual(reloadedStore.presets[0].title, "Daily standup")
    }
}
