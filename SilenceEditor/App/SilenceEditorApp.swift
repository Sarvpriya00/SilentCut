import SwiftUI

@main
struct SilenceEditorApp: App {
    var body: some Scene {
        Window("SilenceEditor", id: "main") {
            MainView()
                .preferredColorScheme(.dark) // Enforce Dark Mode first as per design goals
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
