import Foundation
import XCTest
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

final class ReviewSuppressionStoreTests: XCTestCase {
    func testSuppressedAssetsStayHiddenAcrossStoreInstances() async throws {
        let suiteName = "ReviewSuppressionStoreTests.\(UUID().uuidString)"
        let suppressedAt = Date(timeIntervalSince1970: 1_701_000_000)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test defaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = ReviewSuppressionStore(
            suiteName: suiteName,
            key: "suppressed",
            clock: { suppressedAt }
        )
        let firstItem = makeReviewItem(assetID: "first-photo")
        let secondItem = makeReviewItem(assetID: "second-photo")

        await firstStore.suppress(firstItem)

        let secondStore = ReviewSuppressionStore(suiteName: suiteName, key: "suppressed")
        let visibleItems = await secondStore.filterVisibleItems([firstItem, secondItem])
        let records = await secondStore.suppressedRecords()

        XCTAssertEqual(visibleItems.map(\.id), [secondItem.id])
        XCTAssertEqual(records.map(\.assetID), [firstItem.id])
        XCTAssertEqual(records.first?.captureDate, firstItem.asset.creationDate)
        XCTAssertEqual(records.first?.locationLabel, "Tokyo")
        XCTAssertEqual(records.first?.coordinate, GeoCoordinate(latitude: 35.6895, longitude: 139.6917))
        XCTAssertEqual(records.first?.selectedPrecision, .exact)
        XCTAssertEqual(records.first?.suppressedAt, suppressedAt)
    }

    func testSuppressedRecordsIncludeLegacyIDsWithoutStoredMetadata() async throws {
        let suiteName = "ReviewSuppressionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test defaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(["legacy-photo"], forKey: "suppressed")
        let store = ReviewSuppressionStore(suiteName: suiteName, key: "suppressed")

        let records = await store.suppressedRecords()

        XCTAssertEqual(records.map(\.assetID), ["legacy-photo"])
        XCTAssertNil(records.first?.captureDate)
        XCTAssertNil(records.first?.locationLabel)
        XCTAssertNil(records.first?.coordinate)
        XCTAssertNil(records.first?.selectedPrecision)
    }

    private func makeReviewItem(
        assetID: String,
        options: [LocationOption]? = nil,
        selectedPrecision: LocationPrecision = .exact
    ) -> ReviewItem {
        let asset = PhotoAsset(
            id: assetID,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000),
            hasLocation: false
        )
        let coordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        let locationOptions = options ?? [
            LocationOption(precision: .exact, coordinate: coordinate, label: "Tokyo")
        ]
        let selectedOption = locationOptions.first(where: { $0.precision == selectedPrecision }) ?? locationOptions[0]

        return ReviewItem(
            asset: asset,
            proposedCoordinate: selectedOption.coordinate,
            locationLabel: selectedOption.label,
            confidence: .acceptable,
            timeDelta: 60,
            disposition: .autoSuggested,
            suggestedDecision: MatchDecision(
                assetID: assetID,
                captureDate: asset.creationDate,
                coordinate: selectedOption.coordinate,
                label: selectedOption.label,
                confidence: .acceptable,
                precision: selectedOption.precision
            ),
            availableLocationOptions: locationOptions
        )
    }
}
