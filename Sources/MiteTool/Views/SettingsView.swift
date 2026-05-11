import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var accountSubdomain = ""
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.title3).bold()

            StatusBannerView(infoMessage: viewModel.infoMessage, errorMessage: viewModel.errorMessage)

            GroupBox("MITE Connection") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Account subdomain (e.g. demo)", text: $accountSubdomain)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Requests are sent to https://<subdomain>.mite.de with X-MiteApiKey.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
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
                }
                .padding(.top, 4)
            }

            GroupBox("Current Cache") {
                Text("Projects: \(viewModel.catalogStore.projects.count) • Services: \(viewModel.catalogStore.services.count)")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            accountSubdomain = viewModel.configStore.accountSubdomain
        }
    }
}
