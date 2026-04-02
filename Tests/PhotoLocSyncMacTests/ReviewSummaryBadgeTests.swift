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
                    Includes Auto and Ambiguous items. Excludes No match.
                    """
                ),
                ReviewSummaryBadge(
                    title: "Auto",
                    value: 7,
                    helpText: """
                    Photos with a strong enough timeline match that Photo Loc Sync can prefill a proposed location.
                    Spot-check these before writing changes to Apple Photos.
                    """
                ),
                ReviewSummaryBadge(
                    title: "Ambiguous",
                    value: 4,
                    helpText: """
                    Photos that have one or more possible timeline matches, but not enough certainty to auto-suggest one.
                    Review these manually and choose the right precision before writing.
                    """
                ),
                ReviewSummaryBadge(
                    title: "No match",
                    value: 3,
                    helpText: """
                    Photos that had no usable timeline point near the capture time.
                    They are counted here, but do not appear in the review grid.
                    """
                )
            ]
        )
    }
}
