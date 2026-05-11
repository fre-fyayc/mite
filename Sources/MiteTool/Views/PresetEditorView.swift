import SwiftUI

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let projects: [MiteProject]
    let services: [MiteService]
    let existingPreset: MitePreset?
    let onSave: (MitePreset) -> Void

    @State private var title = ""
    @State private var selectedProjectID: Int?
    @State private var selectedServiceID: Int?
    @State private var note = ""
    @State private var defaultMinutes = 60

    init(
        projects: [MiteProject],
        services: [MiteService],
        existingPreset: MitePreset? = nil,
        onSave: @escaping (MitePreset) -> Void
    ) {
        self.projects = projects
        self.services = services
        self.existingPreset = existingPreset
        self.onSave = onSave
        _title = State(initialValue: existingPreset?.title ?? "")
        _selectedProjectID = State(initialValue: existingPreset?.projectID ?? projects.first?.id)
        _selectedServiceID = State(initialValue: existingPreset?.serviceID ?? services.first?.id)
        _note = State(initialValue: existingPreset?.note ?? "")
        _defaultMinutes = State(initialValue: existingPreset?.defaultMinutes ?? 60)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedProjectID != nil &&
        selectedServiceID != nil &&
        defaultMinutes > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existingPreset == nil ? "Create Preset" : "Edit Preset")
                .font(.headline)

            TextField("Preset title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Project", selection: $selectedProjectID) {
                ForEach(projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }

            Picker("Service", selection: $selectedServiceID) {
                ForEach(services) { service in
                    Text(service.name).tag(Optional(service.id))
                }
            }

            TextField("Default note", text: $note)
                .textFieldStyle(.roundedBorder)

            Stepper("Default minutes: \(defaultMinutes)", value: $defaultMinutes, in: 1...720, step: 5)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    guard let projectID = selectedProjectID, let serviceID = selectedServiceID else { return }
                    onSave(
                        MitePreset(
                            id: existingPreset?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            projectID: projectID,
                            serviceID: serviceID,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            defaultMinutes: defaultMinutes
                        )
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .frame(width: 420)
        .padding(18)
    }
}
