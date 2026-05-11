import Foundation

struct MiteAPIErrorPayload: Decodable {
    let error: String
}

struct MiteProjectEnvelope: Decodable {
    let project: MiteProjectPayload
}

struct MiteProjectPayload: Decodable {
    let id: Int
    let name: String
}

struct MiteServiceEnvelope: Decodable {
    let service: MiteServicePayload
}

struct MiteServicePayload: Decodable {
    let id: Int
    let name: String
}

struct MiteMyselfEnvelope: Decodable {
    let user: MiteMyselfPayload
}

struct MiteMyselfPayload: Decodable {
    let id: Int
    let name: String
}

struct MiteCreateTimeEntryBody: Encodable {
    let timeEntry: MiteCreateTimeEntryPayload

    enum CodingKeys: String, CodingKey {
        case timeEntry = "time_entry"
    }
}

struct MiteCreateTimeEntryPayload: Encodable {
    let projectID: Int
    let serviceID: Int
    let note: String
    let minutes: Int
    let dateAt: String

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case serviceID = "service_id"
        case note
        case minutes
        case dateAt = "date_at"
    }
}
