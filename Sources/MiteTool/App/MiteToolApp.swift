import SwiftUI

@main
struct MiteToolApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("MiteTool") {
            RootTabView()
                .environmentObject(viewModel)
                .frame(minWidth: 920, minHeight: 640)
                .onAppear {
                    AppIconManager.applyGlassIcon()
                }
        }
    }
}
