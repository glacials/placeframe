import SwiftUI

enum AppWindowID {
    static let leftBlankHistory = "left-blank-history"
    static let privacy = "privacy"
}

private struct PhotoLocSyncWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Privacy & Data Handling") {
                openWindow(id: AppWindowID.privacy)
            }
        }

        CommandGroup(after: .windowArrangement) {
            Button("Review Left Blank Photos") {
                openWindow(id: AppWindowID.leftBlankHistory)
            }
        }
    }
}

@main
struct PhotoLocSyncMacApp: App {
    @StateObject private var appState = AppDI.makeAppState()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 720)
        }
        .commands {
            PhotoLocSyncWindowCommands()
        }

        Window("Left Blank Photos", id: AppWindowID.leftBlankHistory) {
            LeftBlankHistoryView(viewModel: appState.leftBlankHistoryViewModel)
        }
        .defaultSize(width: 980, height: 720)

        Window("Privacy & Data Handling", id: AppWindowID.privacy) {
            PrivacyInfoView()
        }
        .defaultSize(width: 760, height: 520)
    }
}
