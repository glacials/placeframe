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

private struct ReviewSessionSource {
    let timeline: ImportedTimeline
    let candidateAssets: [PhotoAsset]
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
    private var reviewSessionSource: ReviewSessionSource?

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
        reviewSessionSource = ReviewSessionSource(
            timeline: preparedReview.timeline,
            candidateAssets: preparedReview.candidateAssets
        )
        await displayPreparedReview(preparedReview)
    }

    func apply(decision: MatchDecision) async throws {
        _ = try await coordinator.apply([decision])
    }

    func deletePhoto(assetID: String) async throws {
        try await coordinator.deleteAsset(withID: assetID)
    }

    func reset() {
        reviewSessionSource = nil
        reviewViewModel = nil
        flowState = .idle
    }

    private func displayPreparedReview(
        _ preparedReview: PreparedReview,
        preferredDayStart: Date? = nil
    ) async {
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
            sessionAssetIDs: Set(preparedReview.candidateAssets.map(\.id)),
            captureTimeOffset: preparedReview.captureTimeOffset,
            captureTimeOffsetAnalysis: preparedReview.captureTimeOffsetAnalysis,
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
            onApplyCaptureTimeOffset: { [weak self] offset, excludedAssetIDs, preferredDayStart in
                guard let self else { return }
                await self.applyCaptureTimeOffset(
                    offset,
                    excluding: excludedAssetIDs,
                    preferredDayStart: preferredDayStart
                )
            },
            onCancel: { [weak self] in
                Task { @MainActor in
                    self?.reset()
                }
            }
        )

        if let preferredDayStart,
           let preferredDayIndex = reviewViewModel.daySections.firstIndex(where: { $0.dayStart == preferredDayStart }) {
            reviewViewModel.currentDayIndex = preferredDayIndex
        }

        self.reviewViewModel = reviewViewModel
        self.flowState = .review
    }

    private func applyCaptureTimeOffset(
        _ offset: TimeInterval,
        excluding excludedAssetIDs: Set<String>,
        preferredDayStart: Date?
    ) async {
        guard let reviewSessionSource else { return }

        let remainingAssets = reviewSessionSource.candidateAssets.filter { asset in
            excludedAssetIDs.contains(asset.id) == false
        }
        let preparedReview = await coordinator.prepareReview(
            timeline: reviewSessionSource.timeline,
            assets: remainingAssets,
            captureTimeOffset: offset
        )
        self.reviewSessionSource = ReviewSessionSource(
            timeline: reviewSessionSource.timeline,
            candidateAssets: remainingAssets
        )
        await displayPreparedReview(preparedReview, preferredDayStart: preferredDayStart)
    }
}
