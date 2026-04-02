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

    func testPlotLayoutCentersSingleCoordinate() {
        let cluster = makeCluster(
            id: "tokyo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        )

        let layout = ReviewMapPlotLayout.make(
            clusters: [cluster],
            selectionTargets: [],
            in: CGSize(width: 400, height: 300)
        )

        XCTAssertEqual(layout.clusterPoints.count, 1)
        XCTAssertEqual(layout.clusterPoints[0].x, 200, accuracy: 0.001)
        XCTAssertEqual(layout.clusterPoints[0].y, 150, accuracy: 0.001)
    }

    func testPlotLayoutPlacesHigherLatitudeNearTopAndHigherLongitudeToTheRight() {
        let southwest = makeCluster(
            id: "southwest",
            coordinate: GeoCoordinate(latitude: 34.0, longitude: 135.0)
        )
        let northeast = makeCluster(
            id: "northeast",
            coordinate: GeoCoordinate(latitude: 36.0, longitude: 140.0)
        )

        let layout = ReviewMapPlotLayout.make(
            clusters: [southwest, northeast],
            selectionTargets: [],
            in: CGSize(width: 400, height: 300)
        )
        let southwestPoint = layout.clusterPoints.first { $0.id == southwest.id }!
        let northeastPoint = layout.clusterPoints.first { $0.id == northeast.id }!

        XCTAssertLessThan(southwestPoint.x, northeastPoint.x)
        XCTAssertGreaterThan(southwestPoint.y, northeastPoint.y)
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

        return ReviewSelection(id: assetID, item: item, copiedFromAssetID: nil)
    }

    private func makeCluster(id: String, coordinate: GeoCoordinate) -> ReviewMapCluster {
        ReviewMapCluster(
            id: id,
            coordinate: coordinate,
            count: 1,
            sampleLabel: id,
            sampleAsset: PhotoAsset(id: id, creationDate: Date(timeIntervalSince1970: 1_700_000_000), hasLocation: false),
            isSelected: false
        )
    }
}
