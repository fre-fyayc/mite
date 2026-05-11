import Foundation

struct MiteProject: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
}

struct MiteService: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
}

struct MitePreset: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var projectID: Int
    var serviceID: Int
    var note: String
    var defaultMinutes: Int
}

struct TimeEntryDraft: Codable, Hashable {
    var projectID: Int?
    var serviceID: Int?
    var note: String
    var minutes: Int
    var date: Date

    static func empty() -> TimeEntryDraft {
        TimeEntryDraft(projectID: nil, serviceID: nil, note: "", minutes: 60, date: .now)
    }
}

struct MiteTimeEntry: Identifiable, Codable, Hashable {
    let id: Int
    let projectID: Int?
    let serviceID: Int?
    let projectName: String?
    let serviceName: String?
    let note: String
    let minutes: Int
    let date: Date
    let createdAt: Date?
}
