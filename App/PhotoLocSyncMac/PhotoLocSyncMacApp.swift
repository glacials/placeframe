import SwiftUI

@main
struct PhotoLocSyncMacApp: App {
    @StateObject private var appState = AppDI.makeAppState()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 720)
        }
    }
}
