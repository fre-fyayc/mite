import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            QuickAddView()
                .tabItem {
                    Label("Quick Add", systemImage: "bolt.fill")
                }
            ManualEntryView()
                .tabItem {
                    Label("Manual", systemImage: "square.and.pencil")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .padding(16)
    }
}
