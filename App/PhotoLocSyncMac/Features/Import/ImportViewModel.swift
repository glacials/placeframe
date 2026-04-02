import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ImportWizardStep: Int, CaseIterable, Identifiable {
    case export
    case upload

    var id: Self { self }
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isFileImporterPresented = false
    @Published var isDropTargeted = false
    @Published private(set) var currentStep: ImportWizardStep = .export

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func presentImporter() {
        currentStep = .upload
        isFileImporterPresented = true
    }

    func advanceToUpload() {
        currentStep = .upload
    }

    func skipCurrentStep() {
        switch currentStep {
        case .export:
            advanceToUpload()
        case .upload:
            presentImporter()
        }
    }

    func reset() {
        currentStep = .export
        isFileImporterPresented = false
        isDropTargeted = false
    }

    func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            currentStep = .upload
            Task { await appState?.importTimeline(from: url) }
        case .failure(let error):
            guard isUserCancellation(error) == false else { return }
            appState?.flowState = .failed(UserPresentableError(title: "Import Failed", message: error.localizedDescription))
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        currentStep = .upload

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            if let error {
                Task { @MainActor in
                    self?.appState?.flowState = .failed(UserPresentableError(title: "Drop Failed", message: error.localizedDescription))
                }
                return
            }

            let url: URL?
            switch item {
            case let data as Data:
                url = URL(dataRepresentation: data, relativeTo: nil)
            case let nsData as NSData:
                url = URL(dataRepresentation: nsData as Data, relativeTo: nil)
            case let string as String:
                url = URL(string: string)
            default:
                url = nil
            }

            guard let url else {
                Task { @MainActor in
                    self?.appState?.flowState = .failed(UserPresentableError(title: "Drop Failed", message: "The dropped item was not a readable file URL."))
                }
                return
            }

            Task { await self?.appState?.importTimeline(from: url) }
        }
        return true
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain &&
            nsError.code == CocoaError.userCancelled.rawValue
    }
}
