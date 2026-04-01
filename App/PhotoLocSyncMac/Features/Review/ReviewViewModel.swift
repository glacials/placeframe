import AppKit
import Foundation
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct ReviewSelection: Identifiable {
    let id: String
    let item: ReviewItem
    var isSelected: Bool
}

struct ReviewDaySection: Identifiable {
    let id: String
    let dayStart: Date
    let title: String
    let subtitle: String
    let entries: [ReviewSelection]
}

struct ReviewMapFocus: Identifiable, Equatable {
    let id: String
    let coordinate: GeoCoordinate
    let label: String
}

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var mapFocus: ReviewMapFocus?
    @Published var currentDayIndex: Int = 0
    @Published private(set) var summary: ReviewSummary
    @Published private(set) var selections: [ReviewSelection]

    let thumbnailProvider: PhotoThumbnailProvider
    private let onApply: @Sendable ([MatchDecision]) async -> Void
    private let onCancel: @Sendable () -> Void
    private let timeFormatter: DateComponentsFormatter
    private let dayTitleFormatter: DateFormatter
    private let calendar = Calendar.autoupdatingCurrent

    init(
        summary: ReviewSummary,
        items: [ReviewItem],
        thumbnailProvider: PhotoThumbnailProvider,
        onApply: @escaping @Sendable ([MatchDecision]) async -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) {
        self.summary = summary
        self.selections = items.map {
            ReviewSelection(id: $0.id, item: $0, isSelected: $0.disposition == .autoSuggested && $0.suggestedDecision != nil)
        }
        self.thumbnailProvider = thumbnailProvider
        self.onApply = onApply
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

    func toggleSelection(for assetID: String) {
        guard let index = selections.firstIndex(where: { $0.id == assetID }),
              selections[index].item.suggestedDecision != nil else {
            return
        }
        selections[index].isSelected.toggle()
    }

    func showOnMap(_ item: ReviewItem) {
        guard let coordinate = item.proposedCoordinate else { return }
        mapFocus = ReviewMapFocus(id: item.id, coordinate: coordinate, label: item.locationLabel)
    }

    func goToPreviousDay() {
        guard canGoToPreviousDay else { return }
        currentDayIndex -= 1
        mapFocus = nil
    }

    func goToNextDay() {
        guard canGoToNextDay else { return }
        currentDayIndex += 1
        mapFocus = nil
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

    func cancel() {
        onCancel()
    }
}
