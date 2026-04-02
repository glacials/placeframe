import Foundation
import PhotoLocSyncCore

struct ReviewSummaryBadge: Hashable, Sendable {
    let title: String
    let value: Int
    let helpText: String

    static func badges(for summary: ReviewSummary) -> [ReviewSummaryBadge] {
        [
            ReviewSummaryBadge(
                title: "Photos",
                value: summary.totalAssets,
                helpText: """
                Reviewable photos from the selected timeline.
                Includes Auto and Ambiguous items. Excludes No match.
                """
            ),
            ReviewSummaryBadge(
                title: "Auto",
                value: summary.autoSuggested,
                helpText: """
                Photos with a strong enough timeline match that Photo Loc Sync can prefill a proposed location.
                Spot-check these before writing changes to Apple Photos.
                """
            ),
            ReviewSummaryBadge(
                title: "Ambiguous",
                value: summary.ambiguous,
                helpText: """
                Photos that have one or more possible timeline matches, but not enough certainty to auto-suggest one.
                Review these manually and choose the right precision before writing.
                """
            ),
            ReviewSummaryBadge(
                title: "No match",
                value: summary.unmatched,
                helpText: """
                Photos that had no usable timeline point near the capture time.
                They are counted here, but do not appear in the review grid.
                """
            )
        ]
    }
}
