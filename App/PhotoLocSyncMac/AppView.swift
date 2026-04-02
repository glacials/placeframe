import SwiftUI

struct AppView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Group {
                switch appState.flowState {
                case .idle:
                    ImportView(viewModel: appState.importViewModel)
                case .importing:
                    ProcessingView(viewModel: .importing)
                case .processing(let stage):
                    ProcessingView(viewModel: ProcessingViewModel(stage: stage))
                case .review:
                    if let reviewViewModel = appState.reviewViewModel {
                        ReviewView(viewModel: reviewViewModel)
                    } else {
                        ContentUnavailableView("No Review Data", systemImage: "photo.on.rectangle.angled")
                    }
                case .failed(let error):
                    VStack(spacing: 16) {
                        ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message))
                        Button("Back to Import") {
                            appState.reset()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(32)
                }
            }
            .animation(.default, value: appState.flowStateScreenKey)

            if appState.isShowingKeyboardShortcuts {
                PhotoLocSyncKeyboardShortcutsOverlay(context: keyboardShortcutContext) {
                    appState.isShowingKeyboardShortcuts = false
                }
                .zIndex(1)
            }
        }
        .background {
            globalKeyboardShortcuts
        }
    }

    private var keyboardShortcutContext: PhotoLocSyncShortcutHelpContext {
        switch appState.flowState {
        case .idle:
            return .import
        case .importing, .processing:
            return .processing
        case .review:
            return .review(canAdjustCaptureTimeOffset: appState.reviewViewModel?.canAdjustCaptureTimeOffset ?? false)
        case .failed:
            return .failed
        }
    }

    private var globalKeyboardShortcuts: some View {
        VStack {
            Button(appState.isShowingKeyboardShortcuts ? "Hide Keyboard Shortcuts" : "Show Keyboard Shortcuts") {
                appState.isShowingKeyboardShortcuts.toggle()
            }
            .keyboardShortcut("/", modifiers: .shift)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
