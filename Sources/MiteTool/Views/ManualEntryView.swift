import SwiftUI

struct ManualEntryView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var selectedProjectID: Int?
    @State private var selectedServiceID: Int?
    @State private var note = ""
    @State private var minutes = 60
    @State private var date = Date.now

    private var canSubmit: Bool {
        selectedProjectID != nil &&
        selectedServiceID != nil &&
        minutes > 0 &&
        !viewModel.isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.sectionSpacing) {
            Text("Manual Entry")
                .font(.title3).bold()

            StatusBannerView(infoMessage: viewModel.infoMessage, errorMessage: viewModel.errorMessage)

            GroupBox("Entry Details") {
                Form {
                    Picker("Project", selection: $selectedProjectID) {
                        Text("Select project").tag(Optional<Int>.none)
                        ForEach(viewModel.catalogStore.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }

                    Picker("Service", selection: $selectedServiceID) {
                        Text("Select service").tag(Optional<Int>.none)
                        ForEach(viewModel.catalogStore.services) { service in
                            Text(service.name).tag(Optional(service.id))
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 1...720, step: 5)

                    TextField("Note", text: $note, prompt: Text("What did you work on?"))
                        .textFieldStyle(.roundedBorder)
                }
                .formStyle(.grouped)
                .frame(minHeight: 220)
            }

            HStack {
                Button("Clear") {
                    selectedProjectID = nil
                    selectedServiceID = nil
                    note = ""
                    minutes = 60
                    date = .now
                    viewModel.clearMessages()
                }
                Spacer()
                Button("Save Entry") {
                    var draft = TimeEntryDraft.empty()
                    draft.projectID = selectedProjectID
                    draft.serviceID = selectedServiceID
                    draft.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.minutes = minutes
                    draft.date = date

                    Task {
                        await viewModel.submitEntry(draft)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }

            DailyEntriesTimelineView(
                entries: viewModel.todayEntries,
                isLoading: viewModel.isLoadingTodayEntries,
                errorMessage: viewModel.entriesErrorMessage,
                projectName: viewModel.projectName(for:),
                serviceName: viewModel.serviceName(for:)
            ) {
                Task { await viewModel.loadTodayEntries(showBannerOnError: true) }
            }
        }
        .padding(LayoutMetrics.windowMargin)
        .task {
            await viewModel.loadTodayEntries()
        }
    }
}
