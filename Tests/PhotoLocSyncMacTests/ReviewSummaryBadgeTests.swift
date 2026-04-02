import XCTest
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

final class ReviewSummaryBadgeTests: XCTestCase {
    func testBadgesExposeCountsAndDescriptions() {
        let summary = ReviewSummary(totalAssets: 12, autoSuggested: 7, ambiguous: 4, unmatched: 3)

        let badges = ReviewSummaryBadge.badges(for: summary)

        XCTAssertEqual(
            badges,
            [
                ReviewSummaryBadge(
                    title: "Photos",
                    value: 12,
                    helpText: """
                    Reviewable photos from the selected timeline.
                    Includes Auto-suggested and Needs review items. Excludes No match.
                    """
                ),
                ReviewSummaryBadge(
                    title: MatchDisposition.autoSuggested.reviewStatusTitle,
                    value: 7,
                    helpText: """
                    Photos with a strong enough time match that Photo Loc Sync prefilled a proposed place.
                    Usually within 15 minutes, or inside a stationary visit.
                    """
                ),
                ReviewSummaryBadge(
                    title: MatchDisposition.ambiguous.reviewStatusTitle,
                    value: 4,
                    helpText: """
                    Photos where a nearby timeline match was found, but the timing was looser.
                    Review these manually before writing.
                    """
                ),
                ReviewSummaryBadge(
                    title: MatchDisposition.unmatched.reviewStatusTitle,
                    value: 3,
                    helpText: """
                    Photos that had no usable timeline point near the capture time.
                    They are counted here, but do not appear in the review list.
                    """
                )
            ]
        )
    }
}
