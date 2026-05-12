import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var accountSubdomain = ""
    @State private var apiKey = ""
    @State private var selectedInterval = ConfigurationStore.defaultIntervalMinutes
    @State private var wholeDayHours = ConfigurationStore.defaultWholeDayHours
    @State private var selectionDisplayMode = ConfigurationStore.defaultSelectionDisplayMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics.sectionSpacing) {
                Text("Settings")
                    .font(.title3).bold()

                StatusBannerView(infoMessage: viewModel.infoMessage, errorMessage: viewModel.errorMessage)

                GroupBox("MITE Connection") {
                    VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                        TextField("Account subdomain (e.g. demo)", text: $accountSubdomain)
                            .textFieldStyle(.roundedBorder)
                        SecureField("API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        Text("Requests are sent to https://<subdomain>.mite.de with X-MiteApiKey.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Spacer()
                            Button("Save Credentials") {
                                Task {
                                    await viewModel.saveConfiguration(
                                        accountSubdomain: accountSubdomain,
                                        apiKey: apiKey
                                    )
                                }
                            }
                            .disabled(accountSubdomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                      apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Test Connection") {
                                Task { await viewModel.testConnection() }
                            }
                            .disabled(viewModel.isBusy)

                            Button("Refresh Projects + Services") {
                                Task { await viewModel.refreshCatalog() }
                            }
                            .disabled(viewModel.isBusy)
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox("Current Cache") {
                    Text("Projects: \(viewModel.catalogStore.projects.count) • Services: \(viewModel.catalogStore.services.count)")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Time Entry Defaults") {
                    VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                        HStack {
                            Text("Interval")
                            Spacer()
                            Picker("Interval", selection: $selectedInterval) {
                                ForEach(ConfigurationStore.allowedIntervals, id: \.self) { interval in
                                    Text("\(interval) min").tag(interval)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        Stepper(
                            "Whole Day Hours: \(wholeDayHours, specifier: "%.1f")",
                            value: $wholeDayHours,
                            in: ConfigurationStore.wholeDayHoursRange,
                            step: 0.5
                        )

                        HStack {
                            Spacer()
                            Button("Save Time Defaults") {
                                viewModel.clearMessages()
                                viewModel.configStore.saveTimeEntryPreferences(
                                    intervalMinutes: selectedInterval,
                                    wholeDayHours: wholeDayHours
                                )
                                viewModel.infoMessage = "Time entry defaults saved."
                            }
                            .disabled(viewModel.isBusy)
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox("Project + Service Selection") {
                    VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                        HStack {
                            Text("Selection Mode")
                            Spacer()
                            Picker("Selection Mode", selection: $selectionDisplayMode) {
                                ForEach(SelectionDisplayMode.allCases, id: \.rawValue) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        HStack {
                            Spacer()
                            Button("Save Selection Mode") {
                                viewModel.clearMessages()
                                viewModel.configStore.saveSelectionPreferences(mode: selectionDisplayMode)
                                viewModel.infoMessage = "Selection preferences saved."
                            }
                            .disabled(viewModel.isBusy)
                        }
                        .padding(.top, 4)

                        Divider().padding(.vertical, 4)

                        HStack(alignment: .top, spacing: LayoutMetrics.sectionSpacing) {
                            VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                                Text("Favorite Projects").font(.headline)
                                if viewModel.catalogStore.projects.isEmpty {
                                    Text("No projects loaded yet.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    List(viewModel.catalogStore.projects) { project in
                                        Toggle(project.name, isOn: projectFavoriteBinding(project.id))
                                    }
                                    .frame(minHeight: 160, maxHeight: 260)
                                }
                            }

                            VStack(alignment: .leading, spacing: LayoutMetrics.compactSpacing) {
                                Text("Favorite Services").font(.headline)
                                if viewModel.catalogStore.services.isEmpty {
                                    Text("No services loaded yet.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    List(viewModel.catalogStore.services) { service in
                                        Toggle(service.name, isOn: serviceFavoriteBinding(service.id))
                                    }
                                    .frame(minHeight: 160, maxHeight: 260)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(LayoutMetrics.windowMargin)
        .onAppear {
            accountSubdomain = viewModel.configStore.accountSubdomain
            selectedInterval = viewModel.configStore.timeEntryIntervalMinutes
            wholeDayHours = viewModel.configStore.wholeDayHours
            selectionDisplayMode = viewModel.configStore.selectionDisplayMode
        }
    }

    private func projectFavoriteBinding(_ projectID: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.configStore.isFavoriteProject(projectID) },
            set: { isFavorite in
                viewModel.configStore.setProjectFavorite(projectID, isFavorite: isFavorite)
            }
        )
    }

    private func serviceFavoriteBinding(_ serviceID: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.configStore.isFavoriteService(serviceID) },
            set: { isFavorite in
                viewModel.configStore.setServiceFavorite(serviceID, isFavorite: isFavorite)
            }
        )
    }
}
