import AppKit
import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct ReviewSelection: Identifiable {
    let id: String
    var item: ReviewItem
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

enum ReviewPhotoSelectionMode {
    case replace
    case toggle
    case range(extendExisting: Bool)
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
    @Published private(set) var isApplyingCurrentDay = false
    @Published private var copiedLocation: CopiedLocation?

    let thumbnailProvider: PhotoThumbnailProvider
    private let onApplyDecision: @Sendable (MatchDecision) async throws -> Void
    private let onDismissPermanently: @Sendable (String) async -> Void
    private let onDeletePhoto: @Sendable (String) async throws -> Void
    private let onCancel: @Sendable () -> Void
    private let timeFormatter: DateComponentsFormatter
    private let dayTitleFormatter: DateFormatter
    private let calendar = Calendar.autoupdatingCurrent
    private let errorPresenter = ErrorPresenter()
    private var actionAssetIDs: Set<String> = []
    private var deletingAssetIDs: Set<String> = []
    private var selectionAnchorID: String?

    init(
        summary: ReviewSummary,
        items: [ReviewItem],
        thumbnailProvider: PhotoThumbnailProvider,
        onApplyDecision: @escaping @Sendable (MatchDecision) async throws -> Void,
        onDismissPermanently: @escaping @Sendable (String) async -> Void,
        onDeletePhoto: @escaping @Sendable (String) async throws -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.summary = summary
        self.selections = items.map {
            ReviewSelection(
                id: $0.id,
                item: $0,
                copiedFromAssetID: nil
            )
        }
        self.thumbnailProvider = thumbnailProvider
        self.onApplyDecision = onApplyDecision
        self.onDismissPermanently = onDismissPermanently
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
            return ReviewDaySection(
                id: dayStart.ISO8601Format(),
                dayStart: dayStart,
                title: dayTitleFormatter.string(from: dayStart),
                subtitle: "\(entries.count) photos",
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
    var canApplyCurrentDay: Bool {
        guard let currentDayEntries = currentDaySection?.entries,
              !currentDayEntries.isEmpty else {
            return false
        }

        return !isApplyingCurrentDay && currentDayEntries.allSatisfy { $0.item.suggestedDecision != nil }
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

    func selectPhoto(_ assetID: String, mode: ReviewPhotoSelectionMode) {
        guard selections.contains(where: { $0.id == assetID }) else { return }

        switch mode {
        case .replace:
            selectedPhotoIDs = [assetID]
            selectionAnchorID = assetID
        case .toggle:
            if selectedPhotoIDs.contains(assetID) {
                selectedPhotoIDs.remove(assetID)
            } else {
                selectedPhotoIDs.insert(assetID)
            }
            selectionAnchorID = assetID
        case .range(let extendExisting):
            selectPhotoRange(to: assetID, extendExisting: extendExisting)
        }
    }

    func copyLocation(for assetID: String) {
        guard let selection = selections.first(where: { $0.id == assetID }),
              let copiedLocation = copiedLocationPayload(for: selection) else {
            return
        }
        self.copiedLocation = copiedLocation
    }

    func canPasteLocation(into assetID: String) -> Bool {
        canPasteLocation(into: [assetID])
    }

    func canPasteLocation(into assetIDs: [String]) -> Bool {
        guard let copiedLocation else {
            return false
        }

        return orderedSelections(for: assetIDs).contains { selection in
            selection.id != copiedLocation.sourceAssetID
        }
    }

    func pasteLocation(into assetID: String) {
        pasteLocation(into: [assetID])
    }

    func pasteLocation(into assetIDs: [String]) {
        guard canPasteLocation(into: assetIDs),
              let copiedLocation else {
            return
        }

        for selection in orderedSelections(for: assetIDs) where selection.id != copiedLocation.sourceAssetID {
            guard let index = selections.firstIndex(where: { $0.id == selection.id }) else {
                continue
            }

            selections[index].item = reviewItem(for: selection, using: copiedLocation)
            selections[index].copiedFromAssetID = copiedLocation.sourceAssetID
        }
    }

    func showOnMap(_ item: ReviewItem) {
        guard item.proposedCoordinate != nil else { return }
        selectedPhotoIDs = [item.id]
        selectionAnchorID = item.id
    }

    func selectAllPhotosOnCurrentDay() {
        guard let currentDayEntries = currentDaySection?.entries,
              !currentDayEntries.isEmpty else {
            return
        }

        let currentDayPhotoIDs = Set(currentDayEntries.map(\.id))
        selectedPhotoIDs = currentDayPhotoIDs

        if let selectionAnchorID, currentDayPhotoIDs.contains(selectionAnchorID) {
            return
        }

        selectionAnchorID = currentDayEntries.first?.id
    }

    func goToPreviousDay() {
        guard canGoToPreviousDay else { return }
        currentDayIndex -= 1
        selectedPhotoIDs.removeAll()
        selectionAnchorID = nil
    }

    func goToNextDay() {
        guard canGoToNextDay else { return }
        currentDayIndex += 1
        selectedPhotoIDs.removeAll()
        selectionAnchorID = nil
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

    func applyChange(for assetID: String) async {
        await applyChanges(for: [assetID])
    }

    func applyCurrentDay() async {
        guard canApplyCurrentDay,
              let currentDayAssetIDs = currentDaySection?.entries.map(\.id),
              !currentDayAssetIDs.isEmpty else {
            return
        }

        isApplyingCurrentDay = true
        defer {
            isApplyingCurrentDay = false
        }

        await applyChanges(for: currentDayAssetIDs)
    }

    func skipForNow(_ assetID: String) {
        skipPhotosForNow([assetID])
    }

    func dismissPermanently(_ assetID: String) async {
        await dismissPhotosPermanently([assetID])
    }

    func applyChanges(for assetIDs: [String]) async {
        let applicableSelections = orderedSelections(for: assetIDs).filter { $0.item.suggestedDecision != nil }
        let applicableAssetIDs = reserveActionAssetIDs(applicableSelections.map(\.id))
        guard !applicableAssetIDs.isEmpty else { return }

        let nextAssetIDAfterAllApplies = nextAssetID(afterRemoving: Set(applicableAssetIDs))

        defer {
            applicableAssetIDs.forEach { actionAssetIDs.remove($0) }
        }

        for assetID in applicableAssetIDs {
            guard let decision = selections.first(where: { $0.id == assetID })?.item.suggestedDecision else {
                continue
            }

            do {
                try await onApplyDecision(decision)
                removeSelection(withID: assetID)
            } catch {
                presentedError = errorPresenter.userPresentableError(for: error)
                focusPhoto(withID: assetID)
                return
            }
        }

        focusPhoto(withID: nextAssetIDAfterAllApplies)
    }

    func skipPhotosForNow(_ assetIDs: [String]) {
        let orderedAssetIDs = orderedSelections(for: assetIDs).map(\.id)
        guard !orderedAssetIDs.isEmpty else { return }

        let nextAssetID = nextAssetID(afterRemoving: Set(orderedAssetIDs))
        removeSelections(withIDs: orderedAssetIDs)
        focusPhoto(withID: nextAssetID)
    }

    func dismissPhotosPermanently(_ assetIDs: [String]) async {
        let orderedAssetIDs = reserveActionAssetIDs(orderedSelections(for: assetIDs).map(\.id))
        guard !orderedAssetIDs.isEmpty else { return }

        let nextAssetID = nextAssetID(afterRemoving: Set(orderedAssetIDs))

        defer {
            orderedAssetIDs.forEach { actionAssetIDs.remove($0) }
        }

        for assetID in orderedAssetIDs {
            await onDismissPermanently(assetID)
        }

        removeSelections(withIDs: orderedAssetIDs)
        focusPhoto(withID: nextAssetID)
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

    private func selectPhotoRange(to assetID: String, extendExisting: Bool) {
        let orderedAssetIDs = currentDaySection?.entries.map(\.id) ?? selections.map(\.id)
        guard let targetIndex = orderedAssetIDs.firstIndex(of: assetID) else { return }

        let anchorID = selectionAnchorID ?? assetID
        guard let anchorIndex = orderedAssetIDs.firstIndex(of: anchorID) else {
            if extendExisting {
                selectedPhotoIDs.insert(assetID)
            } else {
                selectedPhotoIDs = [assetID]
            }
            selectionAnchorID = assetID
            return
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        let rangeSelection = Set(orderedAssetIDs[lowerBound...upperBound])

        if extendExisting {
            selectedPhotoIDs.formUnion(rangeSelection)
        } else {
            selectedPhotoIDs = rangeSelection
        }
    }

    private func orderedSelections(for assetIDs: [String]) -> [ReviewSelection] {
        let targetAssetIDs = Set(assetIDs)
        guard !targetAssetIDs.isEmpty else { return [] }

        let orderedAssetIDs = daySections.flatMap { section in
            section.entries.map(\.id)
        }
        let selectionByID = Dictionary(uniqueKeysWithValues: selections.map { ($0.id, $0) })

        return orderedAssetIDs.compactMap { assetID in
            guard targetAssetIDs.contains(assetID) else { return nil }
            return selectionByID[assetID]
        }
    }

    private func reserveActionAssetIDs(_ assetIDs: [String]) -> [String] {
        var reservedAssetIDs: [String] = []
        reservedAssetIDs.reserveCapacity(assetIDs.count)

        for assetID in assetIDs where actionAssetIDs.insert(assetID).inserted {
            reservedAssetIDs.append(assetID)
        }

        return reservedAssetIDs
    }

    private func nextAssetID(afterRemoving assetIDs: Set<String>) -> String? {
        let orderedAssetIDs = daySections.flatMap { section in
            section.entries.map(\.id)
        }
        guard let firstRemovedIndex = orderedAssetIDs.firstIndex(where: { assetIDs.contains($0) }) else {
            return nil
        }

        for index in firstRemovedIndex..<orderedAssetIDs.count {
            let assetID = orderedAssetIDs[index]
            if assetIDs.contains(assetID) == false {
                return assetID
            }
        }

        return nil
    }

    private func focusPhoto(withID assetID: String?) {
        guard let assetID else {
            selectedPhotoIDs.removeAll()
            selectionAnchorID = nil
            clampCurrentDayIndex()
            return
        }

        guard let dayIndex = daySections.firstIndex(where: { section in
            section.entries.contains(where: { $0.id == assetID })
        }) else {
            selectedPhotoIDs.removeAll()
            selectionAnchorID = nil
            clampCurrentDayIndex()
            return
        }

        currentDayIndex = dayIndex
        selectedPhotoIDs = [assetID]
        selectionAnchorID = assetID
    }

    private func removeSelections(withIDs assetIDs: [String]) {
        let removedAssetIDs = Set(assetIDs)
        guard !removedAssetIDs.isEmpty else { return }

        selections.removeAll { removedAssetIDs.contains($0.id) }
        selectedPhotoIDs.subtract(removedAssetIDs)
        if let selectionAnchorID, removedAssetIDs.contains(selectionAnchorID) {
            self.selectionAnchorID = nil
        }
        if let copiedLocation, removedAssetIDs.contains(copiedLocation.sourceAssetID) {
            self.copiedLocation = nil
        }

        refreshSummary()
        clampCurrentDayIndex()
    }

    private func removeSelection(withID assetID: String) {
        removeSelections(withIDs: [assetID])
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
