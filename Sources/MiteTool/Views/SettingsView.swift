import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var accountSubdomain = ""
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.sectionSpacing) {
            Text("Settings")
                .font(.title3).bold()

            StatusBannerView(infoMessage: viewModel.infoMessage, errorMessage: viewModel.errorMessage)

            GroupBox("MITE Connection") {
                Form {
                    TextField("Account subdomain (e.g. demo)", text: $accountSubdomain)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Requests are sent to https://<subdomain>.mite.de with X-MiteApiKey.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .formStyle(.grouped)
                .frame(minHeight: 150)

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
                .padding(.top, 8)
            }

            GroupBox("Current Cache") {
                Text("Projects: \(viewModel.catalogStore.projects.count) • Services: \(viewModel.catalogStore.services.count)")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(LayoutMetrics.windowMargin)
        .onAppear {
            accountSubdomain = viewModel.configStore.accountSubdomain
        }
    }
}
