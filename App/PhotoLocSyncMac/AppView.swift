import SwiftUI

struct AppView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
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
                }
                .padding(32)
            }
        }
        .animation(.default, value: appState.flowStateScreenKey)
        .sheet(isPresented: $appState.isShowingLocationLabelingConsent) {
            LocationLabelingConsentView { preference in
                appState.chooseLocationLabelingPreference(preference)
            }
            .interactiveDismissDisabled(true)
        }
    }
}
