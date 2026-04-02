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
                Includes Auto-suggested and Needs review items. Excludes No match.
                """
            ),
            ReviewSummaryBadge(
                title: MatchDisposition.autoSuggested.reviewStatusTitle,
                value: summary.autoSuggested,
                helpText: """
                Photos with a strong enough time match that Photo Loc Sync prefilled a proposed place.
                Usually within 15 minutes, or inside a stationary visit.
                """
            ),
            ReviewSummaryBadge(
                title: MatchDisposition.ambiguous.reviewStatusTitle,
                value: summary.ambiguous,
                helpText: """
                Photos where a nearby timeline match was found, but the timing was looser.
                Review these manually before writing.
                """
            ),
            ReviewSummaryBadge(
                title: MatchDisposition.unmatched.reviewStatusTitle,
                value: summary.unmatched,
                helpText: """
                Photos that had no usable timeline point near the capture time.
                They are counted here, but do not appear in the review grid.
                """
            )
        ]
    }
}
