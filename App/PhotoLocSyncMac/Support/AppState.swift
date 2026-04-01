import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct UserPresentableError: Error, Sendable {
    let title: String
    let message: String
}

enum AppFlowState {
    case idle
    case importing
    case processing(ProcessingStage)
    case review
    case applying
    case completed(ApplySummary)
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
    private let errorPresenter: ErrorPresenter

    init(
        coordinator: SyncCoordinator,
        fileReader: ImportedFileReading,
        thumbnailProvider: PhotoThumbnailProvider,
        reviewItemFilter: PhotoKitImportedReviewItemFilter,
        errorPresenter: ErrorPresenter = ErrorPresenter()
    ) {
        self.coordinator = coordinator
        self.fileReader = fileReader
        self.thumbnailProvider = thumbnailProvider
        self.reviewItemFilter = reviewItemFilter
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
        case .applying: "applying"
        case .completed: "completed"
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
        let filteredItems = await reviewItemFilter.filterToLikelyCameraItems(preparedReview.items)
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
            onApply: { [weak self] decisions in
                await self?.apply(decisions: decisions)
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

    func apply(decisions: [MatchDecision]) async {
        flowState = .applying
        do {
            let summary = try await coordinator.apply(decisions)
            flowState = .completed(summary)
        } catch {
            flowState = .failed(errorPresenter.userPresentableError(for: error))
        }
    }

    func reset() {
        reviewViewModel = nil
        flowState = .idle
    }
}
