import MapKit
import XCTest
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

final class ReviewMapViewTests: XCTestCase {
    func testMakeClustersUsesSelectedPhotoAsRepresentativeForGroupedCoordinate() {
        let firstEntry = makeReviewSelection(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.68951, longitude: 139.69171),
            label: "Shinjuku, Tokyo"
        )
        let secondEntry = makeReviewSelection(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 35.68954, longitude: 139.69174),
            label: "Tokyo Metropolitan Government Building"
        )

        let clusters = ReviewMapView.makeClusters(
            entries: [firstEntry, secondEntry],
            selectedPhotoIDs: [secondEntry.id]
        )

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 2)
        XCTAssertEqual(clusters[0].sampleAsset.id, secondEntry.id)
        XCTAssertEqual(clusters[0].sampleLabel, secondEntry.item.locationLabel)
        XCTAssertTrue(clusters[0].isSelected)
    }

    func testMakeClustersSortsLargestGroupFirst() {
        let firstTokyoEntry = makeReviewSelection(
            assetID: "tokyo-a",
            coordinate: GeoCoordinate(latitude: 35.68951, longitude: 139.69171),
            label: "Tokyo"
        )
        let secondTokyoEntry = makeReviewSelection(
            assetID: "tokyo-b",
            coordinate: GeoCoordinate(latitude: 35.68954, longitude: 139.69174),
            label: "Tokyo"
        )
        let osakaEntry = makeReviewSelection(
            assetID: "osaka-a",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka"
        )

        let clusters = ReviewMapView.makeClusters(
            entries: [osakaEntry, firstTokyoEntry, secondTokyoEntry],
            selectedPhotoIDs: []
        )

        XCTAssertEqual(clusters.map(\.count), [2, 1])
        XCTAssertEqual(clusters.first?.sampleAsset.id, firstTokyoEntry.id)
        XCTAssertEqual(clusters.first?.sampleLabel, "Tokyo")
        XCTAssertFalse(clusters.first?.isSelected ?? true)
    }

    func testViewportSnapshotIgnoresMinorCameraDrift() {
        let expected = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917),
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        )
        let current = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6901, longitude: 139.6921),
                span: MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.0158)
            )
        )

        XCTAssertFalse(current.isMeaningfullyDifferent(from: expected))
    }

    func testViewportSnapshotDetectsMeaningfulPanAway() {
        let expected = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917),
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        )
        let current = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6955, longitude: 139.6995),
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        )

        XCTAssertTrue(current.isMeaningfullyDifferent(from: expected))
    }

    func testViewportSnapshotDetectsMeaningfulZoomChange() {
        let expected = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        let current = ReviewMapViewportSnapshot(
            region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
                span: MKCoordinateSpan(latitudeDelta: 0.0185, longitudeDelta: 0.0185)
            )
        )

        XCTAssertTrue(current.isMeaningfullyDifferent(from: expected))
    }

    private func makeReviewSelection(
        assetID: String,
        coordinate: GeoCoordinate,
        label: String
    ) -> ReviewSelection {
        let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = PhotoAsset(id: assetID, creationDate: creationDate, hasLocation: false)
        let item = ReviewItem(
            asset: asset,
            proposedCoordinate: coordinate,
            locationLabel: label,
            confidence: .excellent,
            timeDelta: nil,
            disposition: .autoSuggested,
            suggestedDecision: nil
        )

        return ReviewSelection(
            id: assetID,
            item: item,
            copiedFromAssetID: nil,
            saveChoice: .location
        )
    }
}
