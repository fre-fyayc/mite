import SwiftUI

struct DailyEntriesTimelineView: View {
    let entries: [MiteTimeEntry]
    let isLoading: Bool
    let errorMessage: String?
    let projectName: (MiteTimeEntry) -> String
    let serviceName: (MiteTimeEntry) -> String
    let refreshAction: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                HStack {
                    Text("My Today’s Entries")
                        .font(.headline)
                    Spacer()
                    Button("Refresh", action: refreshAction)
                        .disabled(isLoading)
                }

                if isLoading {
                    HStack(spacing: LayoutMetrics.compactSpacing) {
                        ProgressView()
                        Text("Loading entries...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if entries.isEmpty {
                    ContentUnavailableView(
                        "No Entries Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Entries created today will appear here.")
                    )
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(Self.timeText(for: entry))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text("\(entry.minutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(projectName(entry)) • \(serviceName(entry))")
                                .font(.subheadline)
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(minHeight: 180)
                }
            }
            .padding(.top, 4)
        }
    }

    private static func timeText(for entry: MiteTimeEntry) -> String {
        if let createdAt = entry.createdAt {
            return timeFormatter.string(from: createdAt)
        }
        return "Day entry"
    }
}
