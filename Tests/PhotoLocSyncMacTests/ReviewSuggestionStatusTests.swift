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

    func testLegendDescriptionsExplainEachStatusMeaning() {
        XCTAssertEqual(
            MatchDisposition.autoSuggested.reviewStatusLegendDescription,
            "Strong enough time match that the app prefilled the location. Usually within 15 minutes, or inside a stationary visit."
        )
        XCTAssertEqual(
            MatchDisposition.ambiguous.reviewStatusLegendDescription,
            "A nearby timeline match was found, but it was loose enough that you should double-check it. Usually within 60 minutes."
        )
        XCTAssertEqual(
            MatchDisposition.unmatched.reviewStatusLegendDescription,
            "No nearby timeline evidence was usable, or there was a large gap in timeline coverage, so the photo is left out of review."
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
