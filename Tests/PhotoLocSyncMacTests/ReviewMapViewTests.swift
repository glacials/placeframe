import MapKit
import XCTest
@testable import PhotoLocSyncMac

final class ReviewMapViewTests: XCTestCase {
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
}
