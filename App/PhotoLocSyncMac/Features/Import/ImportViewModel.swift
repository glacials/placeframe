import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isFileImporterPresented = false
    @Published var isDropTargeted = false

    private weak var appState: AppState?

    func bind(appState: AppState) {
        self.appState = appState
    }

    func presentImporter() {
        isFileImporterPresented = true
    }

    func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { await appState?.importTimeline(from: url) }
        case .failure(let error):
            appState?.flowState = .failed(UserPresentableError(title: "Import Failed", message: error.localizedDescription))
        }
    }

    func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

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
}
