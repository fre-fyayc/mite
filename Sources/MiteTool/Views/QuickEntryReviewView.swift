import SwiftUI

struct QuickEntryReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel

    let projects: [MiteProject]
    let services: [MiteService]
    let presetTitle: String
    let onSubmit: (TimeEntryDraft) -> Void

    @State private var selectedProjectID: Int?
    @State private var selectedServiceID: Int?
    @State private var note: String
    @State private var minutes: Int
    @State private var date: Date
    @State private var isWholeDay = false

    private var selectableProjects: [MiteProject] {
        viewModel.preferredProjects(include: selectedProjectID)
    }

    private var selectableServices: [MiteService] {
        viewModel.preferredServices(include: selectedServiceID)
    }

    init(
        presetTitle: String,
        initialDraft: TimeEntryDraft,
        projects: [MiteProject],
        services: [MiteService],
        onSubmit: @escaping (TimeEntryDraft) -> Void
    ) {
        self.presetTitle = presetTitle
        self.projects = projects
        self.services = services
        self.onSubmit = onSubmit
        _selectedProjectID = State(initialValue: initialDraft.projectID ?? projects.first?.id)
        _selectedServiceID = State(initialValue: initialDraft.serviceID ?? services.first?.id)
        _note = State(initialValue: initialDraft.note)
        _minutes = State(initialValue: max(1, initialDraft.minutes))
        _date = State(initialValue: initialDraft.date)
    }

    private var canSave: Bool {
        selectedProjectID != nil &&
        selectedServiceID != nil &&
        minutes > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Entry")
                .font(.headline)
            Text("Preset: \(presetTitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Project", selection: $selectedProjectID) {
                ForEach(selectableProjects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }

            Picker("Service", selection: $selectedServiceID) {
                ForEach(selectableServices) { service in
                    Text(service.name).tag(Optional(service.id))
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)
            Toggle("Whole Day", isOn: $isWholeDay)
                .onChange(of: isWholeDay) { _, newValue in
                    if newValue {
                        minutes = viewModel.configStore.wholeDayMinutes
                    }
                }
            Stepper(
                "Minutes: \(minutes)",
                value: $minutes,
                in: 1...720,
                step: viewModel.configStore.timeEntryIntervalMinutes
            )
            .disabled(isWholeDay)

            TextField("Note", text: $note, prompt: Text("What did you work on?"))
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save Entry") {
                    var draft = TimeEntryDraft.empty()
                    draft.projectID = selectedProjectID
                    draft.serviceID = selectedServiceID
                    draft.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.minutes = minutes
                    draft.date = date
                    onSubmit(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(18)
        .frame(width: 440)
        .onChange(of: viewModel.configStore.wholeDayHours) { _, _ in
            if isWholeDay {
                minutes = viewModel.configStore.wholeDayMinutes
            }
        }
    }
}
