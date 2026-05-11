import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var selectedPreset: MitePreset?
    @State private var showCreatePreset = false
    @State private var editingPreset: MitePreset?
    @State private var showReviewEntry = false
    @State private var reviewDraft = TimeEntryDraft.empty()
    @State private var reviewPresetTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recurring Presets")
                    .font(.title3).bold()
                Spacer()
                Button("New Preset") {
                    showCreatePreset = true
                }
                .disabled(viewModel.catalogStore.projects.isEmpty || viewModel.catalogStore.services.isEmpty)
            }

            StatusBannerView(infoMessage: viewModel.infoMessage, errorMessage: viewModel.errorMessage)

            if viewModel.presetStore.presets.isEmpty {
                ContentUnavailableView(
                    "No Presets Yet",
                    systemImage: "tray",
                    description: Text("Create a preset for recurring work. Refresh catalog in Settings first if needed.")
                )
            } else {
                List(selection: $selectedPreset) {
                    ForEach(viewModel.presetStore.presets) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.title).font(.headline)
                            Text("\(projectName(for: preset.projectID)) • \(serviceName(for: preset.serviceID))")
                                .foregroundStyle(.secondary)
                            if !preset.note.isEmpty {
                                Text(preset.note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(preset)
                        .contextMenu {
                            Button("Edit") {
                                editingPreset = preset
                            }
                            Button("Delete", role: .destructive) {
                                viewModel.deletePreset(id: preset.id)
                            }
                        }
                    }
                    .onMove(perform: movePresets)
                }
            }

            HStack {
                Button("Move Up") { moveSelection(delta: -1) }
                    .disabled(selectedPreset == nil)
                Button("Move Down") { moveSelection(delta: 1) }
                    .disabled(selectedPreset == nil)
                Spacer()
                Button("Log Selected Preset") {
                    if let selectedPreset {
                        prepareReviewEntry(for: selectedPreset)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPreset == nil || viewModel.isBusy)
            }
        }
        .sheet(isPresented: $showCreatePreset) {
            PresetEditorView(
                projects: viewModel.catalogStore.projects,
                services: viewModel.catalogStore.services
            ) { preset in
                viewModel.addPreset(preset)
            }
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorView(
                projects: viewModel.catalogStore.projects,
                services: viewModel.catalogStore.services,
                existingPreset: preset
            ) { updatedPreset in
                viewModel.updatePreset(updatedPreset)
            }
        }
        .sheet(isPresented: $showReviewEntry) {
            QuickEntryReviewView(
                presetTitle: reviewPresetTitle,
                initialDraft: reviewDraft,
                projects: viewModel.catalogStore.projects,
                services: viewModel.catalogStore.services
            ) { draft in
                Task {
                    await viewModel.submitEntry(draft)
                }
            }
        }
    }

    private func prepareReviewEntry(for preset: MitePreset) {
        var draft = TimeEntryDraft.empty()
        draft.projectID = preset.projectID
        draft.serviceID = preset.serviceID
        draft.note = preset.note
        draft.minutes = max(1, preset.defaultMinutes)
        reviewDraft = draft
        reviewPresetTitle = preset.title
        showReviewEntry = true
    }

    private func projectName(for id: Int) -> String {
        viewModel.catalogStore.projects.first(where: { $0.id == id })?.name ?? "Unknown project"
    }

    private func serviceName(for id: Int) -> String {
        viewModel.catalogStore.services.first(where: { $0.id == id })?.name ?? "Unknown service"
    }

    private func movePresets(from source: IndexSet, to destination: Int) {
        viewModel.movePresets(fromOffsets: source, toOffset: destination)
    }

    private func moveSelection(delta: Int) {
        guard let selectedPreset,
              let currentIndex = viewModel.presetStore.presets.firstIndex(of: selectedPreset) else {
            return
        }
        let target = currentIndex + delta
        guard target >= 0 && target < viewModel.presetStore.presets.count else { return }
        viewModel.movePresets(fromOffsets: IndexSet(integer: currentIndex), toOffset: target > currentIndex ? target + 1 : target)
        self.selectedPreset = viewModel.presetStore.presets[target]
    }
}
