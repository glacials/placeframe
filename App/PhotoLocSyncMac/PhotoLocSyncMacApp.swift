import SwiftUI

enum AppWindowID {
    static let leftBlankHistory = "left-blank-history"
    static let about = "about"
}

private struct PhotoLocSyncWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About PhotoLocSyncMac") {
                openWindow(id: AppWindowID.about)
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

        Window("About PhotoLocSyncMac", id: AppWindowID.about) {
            AboutPhotoLocSyncView()
        }
        .defaultSize(width: 540, height: 320)

        Settings {
            LocationLabelingSettingsView(settings: appState.locationLabelingSettings)
        }
    }
}
