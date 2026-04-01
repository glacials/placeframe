import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct UserPresentableError: Error, Sendable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum AppFlowState {
    case idle
    case importing
    case processing(ProcessingStage)
    case review
    case failed(UserPresentableError)
}

@MainActor
final class AppState: ObservableObject {
    @Published var flowState: AppFlowState = .idle
    @Published var reviewViewModel: ReviewViewModel?

    let importViewModel: ImportViewModel

    private let coordinator: SyncCoordinator
    private let fileReader: ImportedFileReading
    private let thumbnailProvider: PhotoThumbnailProvider
    private let reviewItemFilter: PhotoKitImportedReviewItemFilter
    private let reviewSuppressionStore: ReviewSuppressionStoring
    private let errorPresenter: ErrorPresenter

    init(
        coordinator: SyncCoordinator,
        fileReader: ImportedFileReading,
        thumbnailProvider: PhotoThumbnailProvider,
        reviewItemFilter: PhotoKitImportedReviewItemFilter,
        reviewSuppressionStore: ReviewSuppressionStoring,
        errorPresenter: ErrorPresenter = ErrorPresenter()
    ) {
        self.coordinator = coordinator
        self.fileReader = fileReader
        self.thumbnailProvider = thumbnailProvider
        self.reviewItemFilter = reviewItemFilter
        self.reviewSuppressionStore = reviewSuppressionStore
        self.errorPresenter = errorPresenter
        self.importViewModel = ImportViewModel()
        self.importViewModel.bind(appState: self)
    }

    var flowStateScreenKey: String {
        switch flowState {
        case .idle: "idle"
        case .importing: "importing"
        case .processing(let stage): "processing-\(stage.rawValue)"
        case .review: "review"
        case .failed: "failed"
        }
    }

    func importTimeline(from url: URL) async {
        flowState = .importing
        do {
            let data = try await Task.detached(priority: .userInitiated) { [fileReader] in
                try fileReader.readData(from: url)
            }.value
            try await importTimelineData(data)
        } catch {
            flowState = .failed(errorPresenter.userPresentableError(for: error))
        }
    }

    func importTimelineData(_ data: Data) async throws {
        flowState = .processing(.readingTimeline)
        let preparedReview = try await coordinator.prepareReview(from: data) { [weak self] stage in
            Task { @MainActor in
                self?.flowState = .processing(stage)
            }
        }
        let likelyCameraItems = await reviewItemFilter.filterToLikelyCameraItems(preparedReview.items)
        let filteredItems = await reviewSuppressionStore.filterVisibleItems(likelyCameraItems)
        let filteredSummary = ReviewSummary(
            totalAssets: filteredItems.count,
            autoSuggested: filteredItems.filter { $0.disposition == .autoSuggested }.count,
            ambiguous: filteredItems.filter { $0.disposition == .ambiguous }.count,
            unmatched: preparedReview.summary.unmatched
        )

        let reviewViewModel = ReviewViewModel(
            summary: filteredSummary,
            items: filteredItems,
            thumbnailProvider: thumbnailProvider,
            onApplyDecision: { [weak self] decision in
                guard let self else { return }
                try await self.apply(decision: decision)
            },
            onDismissPermanently: { [weak self] assetID in
                guard let self else { return }
                await self.reviewSuppressionStore.suppress(assetID)
            },
            onDeletePhoto: { [weak self] assetID in
                guard let self else { return }
                try await self.deletePhoto(assetID: assetID)
            },
            onCancel: { [weak self] in
                Task { @MainActor in
                    self?.reset()
                }
            }
        )
        self.reviewViewModel = reviewViewModel
        self.flowState = .review
    }

    func apply(decision: MatchDecision) async throws {
        _ = try await coordinator.apply([decision])
    }

    func deletePhoto(assetID: String) async throws {
        try await coordinator.deleteAsset(withID: assetID)
    }

    func reset() {
        reviewViewModel = nil
        flowState = .idle
    }
}
