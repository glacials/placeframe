import Foundation
import XCTest
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

final class ReviewSuppressionStoreTests: XCTestCase {
    func testSuppressedAssetsStayHiddenAcrossStoreInstances() async throws {
        let suiteName = "ReviewSuppressionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test defaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = ReviewSuppressionStore(suiteName: suiteName, key: "suppressed")
        let firstItem = makeReviewItem(assetID: "first-photo")
        let secondItem = makeReviewItem(assetID: "second-photo")

        await firstStore.suppress(firstItem.id)

        let secondStore = ReviewSuppressionStore(suiteName: suiteName, key: "suppressed")
        let visibleItems = await secondStore.filterVisibleItems([firstItem, secondItem])

        XCTAssertEqual(visibleItems.map(\.id), [secondItem.id])
    }

    private func makeReviewItem(assetID: String) -> ReviewItem {
        let asset = PhotoAsset(
            id: assetID,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000),
            hasLocation: false
        )
        let coordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)

        return ReviewItem(
            asset: asset,
            proposedCoordinate: coordinate,
            locationLabel: "Tokyo",
            confidence: .acceptable,
            timeDelta: 60,
            disposition: .autoSuggested,
            suggestedDecision: MatchDecision(
                assetID: assetID,
                captureDate: asset.creationDate,
                coordinate: coordinate,
                label: "Tokyo",
                confidence: .acceptable
            )
        )
    }
}
