import SwiftUI

private enum AppWindowID {
    static let leftBlankHistory = "left-blank-history"
}

private struct PhotoLocSyncWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
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
    }
}
