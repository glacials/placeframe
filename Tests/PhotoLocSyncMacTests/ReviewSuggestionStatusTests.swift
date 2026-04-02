import XCTest
@testable import PhotoLocSyncMac
import PhotoLocSyncCore

final class ReviewSuggestionStatusTests: XCTestCase {
    func testExcellentAutoSuggestedStatusUsesPlainLanguage() {
        let descriptor = ReviewSuggestionStatusDescriptor(
            item: makeReviewItem(confidence: .excellent, disposition: .autoSuggested, timeDelta: 8 * 60)
        )

        XCTAssertEqual(descriptor.title, "8 min")
        XCTAssertEqual(descriptor.symbolName, "checkmark.seal.fill")
        XCTAssertEqual(
            descriptor.shortDescription,
            "Strong enough time match that the app prefilled this location."
        )
    }

    func testAmbiguousStatusExplainsManualVerification() {
        let descriptor = ReviewSuggestionStatusDescriptor(
            item: makeReviewItem(confidence: .maybe, disposition: .ambiguous, timeDelta: 42 * 60)
        )

        XCTAssertEqual(descriptor.title, "42 min")
        XCTAssertEqual(descriptor.symbolName, "questionmark.circle")
        XCTAssertEqual(
            descriptor.shortDescription,
            "A nearby timeline match was found, but it was loose enough that you should verify it before writing."
        )
    }

    func testUnmatchedStatusFallsBackToNoMatchWithoutTimeDelta() {
        let descriptor = ReviewSuggestionStatusDescriptor(
            item: makeReviewItem(confidence: .rejected, disposition: .unmatched, timeDelta: nil)
        )

        XCTAssertEqual(descriptor.title, "No match")
        XCTAssertEqual(descriptor.symbolName, "xmark.circle")
        XCTAssertEqual(
            descriptor.shortDescription,
            "The timeline did not have a usable match for this photo."
        )
    }

    func testHelpContentExplainsMinuteValueAndSignedOffset() {
        let content = ReviewSuggestionStatusHelpContent(
            item: makeReviewItem(confidence: .excellent, disposition: .autoSuggested, timeDelta: 8 * 60)
        )

        XCTAssertEqual(
            content.minuteExplanation,
            "This 8 min badge means the matched Google Timeline point is 8 minutes away from the photo's camera timestamp."
        )
        XCTAssertEqual(
            content.directionExplanation,
            "The badge uses the absolute gap only. A positive drift means the matched timeline point was after the photo, and a negative drift means it was before."
        )
        XCTAssertEqual(
            content.colorExplanation,
            "Green means the timing was strong enough that the app prefilled the location for you."
        )
    }

    func testHelpContentExplainsMissingMinuteGapForUnmatchedItems() {
        let content = ReviewSuggestionStatusHelpContent(
            item: makeReviewItem(confidence: .rejected, disposition: .unmatched, timeDelta: nil)
        )

        XCTAssertEqual(
            content.minuteExplanation,
            "No usable Google Timeline point was close enough to calculate a minute gap for this photo."
        )
        XCTAssertEqual(
            content.directionExplanation,
            "When a timeline point is missing or falls inside a large coverage gap, the app cannot show a minute badge."
        )
        XCTAssertEqual(
            content.colorExplanation,
            "Gray means the timeline did not have a usable nearby match for this photo."
        )
    }

    private func makeReviewItem(
        confidence: MatchConfidence,
        disposition: MatchDisposition,
        timeDelta: TimeInterval?
    ) -> ReviewItem {
        let asset = PhotoAsset(
            id: "asset-1",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            hasLocation: false
        )
        let coordinate = GeoCoordinate(latitude: 35.0, longitude: 139.0)

        return ReviewItem(
            asset: asset,
            proposedCoordinate: coordinate,
            locationLabel: "Shibuya, Tokyo",
            confidence: confidence,
            timeDelta: timeDelta,
            disposition: disposition,
            suggestedDecision: MatchDecision(
                assetID: asset.id,
                captureDate: asset.creationDate,
                coordinate: coordinate,
                label: "Shibuya, Tokyo",
                confidence: confidence,
                precision: .exact
            ),
            availableLocationOptions: [
                LocationOption(
                    precision: .exact,
                    coordinate: coordinate,
                    label: "Shibuya, Tokyo"
                )
            ]
        )
    }
}
