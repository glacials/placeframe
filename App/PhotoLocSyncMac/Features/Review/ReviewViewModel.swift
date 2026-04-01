import AppKit
import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct ReviewSelection: Identifiable {
    let id: String
    var item: ReviewItem
    var isSelected: Bool
    var copiedFromAssetID: String?
}

struct ReviewDaySection: Identifiable {
    let id: String
    let dayStart: Date
    let title: String
    let subtitle: String
    let entries: [ReviewSelection]
}

struct ReviewMapSelectionTarget: Identifiable, Equatable {
    let id: String
    let coordinate: GeoCoordinate
    let label: String
}

private struct CopiedLocation {
    let sourceAssetID: String
    let coordinate: GeoCoordinate
    let label: String
    let confidence: MatchConfidence
}

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var currentDayIndex: Int = 0
    @Published var presentedError: UserPresentableError?
    @Published private(set) var summary: ReviewSummary
    @Published private(set) var selections: [ReviewSelection]
    @Published private(set) var selectedPhotoIDs: Set<String> = []
    @Published private var copiedLocation: CopiedLocation?

    let thumbnailProvider: PhotoThumbnailProvider
    private let onApply: @Sendable ([MatchDecision]) async -> Void
    private let onDeletePhoto: @Sendable (String) async throws -> Void
    private let onCancel: @Sendable () -> Void
    private let timeFormatter: DateComponentsFormatter
    private let dayTitleFormatter: DateFormatter
    private let calendar = Calendar.autoupdatingCurrent
    private let errorPresenter = ErrorPresenter()
    private var deletingAssetIDs: Set<String> = []

    init(
        summary: ReviewSummary,
        items: [ReviewItem],
        thumbnailProvider: PhotoThumbnailProvider,
        onApply: @escaping @Sendable ([MatchDecision]) async -> Void,
        onDeletePhoto: @escaping @Sendable (String) async throws -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.summary = summary
        self.selections = items.map {
            ReviewSelection(
                id: $0.id,
                item: $0,
                isSelected: $0.disposition == .autoSuggested && $0.suggestedDecision != nil,
                copiedFromAssetID: nil
            )
        }
        self.thumbnailProvider = thumbnailProvider
        self.onApply = onApply
        self.onDeletePhoto = onDeletePhoto
        self.onCancel = onCancel

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        self.timeFormatter = formatter

        let titleFormatter = DateFormatter()
        titleFormatter.dateStyle = .full
        titleFormatter.timeStyle = .none
        self.dayTitleFormatter = titleFormatter
    }

    var selectedCount: Int {
        selections.filter(\.isSelected).count
    }

    var emptyStateDescription: String {
        if summary.unmatched > 0 {
            let noun = summary.unmatched == 1 ? "photo" : "photos"
            return "\(summary.unmatched) \(noun) had no timeline match, so nothing is shown for review."
        }
        return "No reviewable photos were found for the selected timeline."
    }

    var daySections: [ReviewDaySection] {
        let grouped = Dictionary(grouping: selections) { selection in
            calendar.startOfDay(for: selection.item.asset.creationDate)
        }

        return grouped.keys.sorted().map { dayStart in
            let entries = grouped[dayStart, default: []]
                .sorted { $0.item.asset.creationDate < $1.item.asset.creationDate }
            let selectedCount = entries.filter(\.isSelected).count
            return ReviewDaySection(
                id: dayStart.ISO8601Format(),
                dayStart: dayStart,
                title: dayTitleFormatter.string(from: dayStart),
                subtitle: "\(entries.count) photos • \(selectedCount) selected",
                entries: entries
            )
        }
    }

    var currentDaySection: ReviewDaySection? {
        guard daySections.indices.contains(currentDayIndex) else { return nil }
        return daySections[currentDayIndex]
    }

    var canGoToPreviousDay: Bool { currentDayIndex > 0 }
    var canGoToNextDay: Bool { currentDayIndex + 1 < daySections.count }

    var selectedDecisions: [MatchDecision] {
        selections.compactMap { selection in
            selection.isSelected ? selection.item.suggestedDecision : nil
        }
    }

    var mapSelectionTargets: [ReviewMapSelectionTarget] {
        selections.compactMap { selection in
            guard selectedPhotoIDs.contains(selection.id),
                  let coordinate = selection.item.proposedCoordinate else {
                return nil
            }

            return ReviewMapSelectionTarget(
                id: selection.id,
                coordinate: coordinate,
                label: selection.item.locationLabel
            )
        }
    }

    func toggleSelection(for assetID: String) {
        guard let index = selections.firstIndex(where: { $0.id == assetID }),
              selections[index].item.suggestedDecision != nil else {
            return
        }
        selections[index].isSelected.toggle()
    }

    func selectPhoto(_ assetID: String, extendingSelection: Bool) {
        guard selections.contains(where: { $0.id == assetID }) else { return }

        if extendingSelection {
            if selectedPhotoIDs.contains(assetID) {
                selectedPhotoIDs.remove(assetID)
            } else {
                selectedPhotoIDs.insert(assetID)
            }
            return
        }

        selectedPhotoIDs = [assetID]
    }

    func copyLocation(for assetID: String) {
        guard let selection = selections.first(where: { $0.id == assetID }),
              let copiedLocation = copiedLocationPayload(for: selection) else {
            return
        }
        self.copiedLocation = copiedLocation
    }

    func canPasteLocation(into assetID: String) -> Bool {
        guard selections.contains(where: { $0.id == assetID }),
              let copiedLocation else {
            return false
        }
        return copiedLocation.sourceAssetID != assetID
    }

    func pasteLocation(into assetID: String) {
        guard canPasteLocation(into: assetID),
              let copiedLocation,
              let index = selections.firstIndex(where: { $0.id == assetID }) else {
            return
        }

        let selection = selections[index]
        selections[index].item = reviewItem(for: selection, using: copiedLocation)
        selections[index].isSelected = true
        selections[index].copiedFromAssetID = copiedLocation.sourceAssetID
    }

    func showOnMap(_ item: ReviewItem) {
        guard item.proposedCoordinate != nil else { return }
        selectedPhotoIDs = [item.id]
    }

    func goToPreviousDay() {
        guard canGoToPreviousDay else { return }
        currentDayIndex -= 1
        selectedPhotoIDs.removeAll()
    }

    func goToNextDay() {
        guard canGoToNextDay else { return }
        currentDayIndex += 1
        selectedPhotoIDs.removeAll()
    }

    func formattedCaptureDate(for item: ReviewItem) -> String {
        item.asset.creationDate.formatted(date: .abbreviated, time: .shortened)
    }

    func formattedTimeDelta(for item: ReviewItem) -> String {
        guard let timeDelta = item.timeDelta else { return "—" }
        let prefix = timeDelta >= 0 ? "+" : "−"
        let magnitude = timeFormatter.string(from: abs(timeDelta)) ?? "0m"
        return prefix + magnitude
    }

    func apply() {
        Task { await onApply(selectedDecisions) }
    }

    func deletePhoto(_ assetID: String) async {
        guard selections.contains(where: { $0.id == assetID }),
              deletingAssetIDs.insert(assetID).inserted else {
            return
        }

        defer {
            deletingAssetIDs.remove(assetID)
        }

        do {
            try await onDeletePhoto(assetID)
            removeSelection(withID: assetID)
        } catch {
            presentedError = errorPresenter.userPresentableError(for: error)
        }
    }

    func cancel() {
        onCancel()
    }

    private func copiedLocationPayload(for selection: ReviewSelection) -> CopiedLocation? {
        if let decision = selection.item.suggestedDecision {
            return CopiedLocation(
                sourceAssetID: selection.id,
                coordinate: decision.coordinate,
                label: decision.label,
                confidence: decision.confidence
            )
        }

        guard let coordinate = selection.item.proposedCoordinate else {
            return nil
        }

        return CopiedLocation(
            sourceAssetID: selection.id,
            coordinate: coordinate,
            label: selection.item.locationLabel,
            confidence: selection.item.confidence
        )
    }

    private func reviewItem(for selection: ReviewSelection, using copiedLocation: CopiedLocation) -> ReviewItem {
        let decision = MatchDecision(
            assetID: selection.item.asset.id,
            captureDate: selection.item.asset.creationDate,
            coordinate: copiedLocation.coordinate,
            label: copiedLocation.label,
            confidence: copiedLocation.confidence
        )

        return ReviewItem(
            asset: selection.item.asset,
            proposedCoordinate: copiedLocation.coordinate,
            locationLabel: copiedLocation.label,
            confidence: copiedLocation.confidence,
            timeDelta: selection.item.timeDelta,
            disposition: selection.item.disposition,
            suggestedDecision: decision
        )
    }

    private func removeSelection(withID assetID: String) {
        selections.removeAll { $0.id == assetID }
        selectedPhotoIDs.remove(assetID)
        if copiedLocation?.sourceAssetID == assetID {
            copiedLocation = nil
        }

        refreshSummary()
        clampCurrentDayIndex()
    }

    private func refreshSummary() {
        summary = ReviewSummary(
            totalAssets: selections.count,
            autoSuggested: selections.filter { $0.item.disposition == .autoSuggested }.count,
            ambiguous: selections.filter { $0.item.disposition == .ambiguous }.count,
            unmatched: summary.unmatched
        )
    }

    private func clampCurrentDayIndex() {
        let lastIndex = max(daySections.count - 1, 0)
        currentDayIndex = min(currentDayIndex, lastIndex)
    }
}
