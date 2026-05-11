import SwiftUI

struct StatusBannerView: View {
    let infoMessage: String?
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let infoMessage, !infoMessage.isEmpty {
                Text(infoMessage)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            }
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
            }
        }
    }
}
