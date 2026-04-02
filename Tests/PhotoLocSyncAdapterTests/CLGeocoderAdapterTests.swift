import XCTest
@testable import PhotoLocSyncAdapters
@testable import PhotoLocSyncCore

final class CLGeocoderAdapterTests: XCTestCase {
    func testAnonymizedCoordinateRoundsToTwoDecimalPlaces() {
        let coordinate = GeoCoordinate(latitude: 37.33182, longitude: -122.03118)

        let anonymized = CLGeocoderAdapter.anonymizedCoordinate(for: coordinate)

        XCTAssertEqual(anonymized.latitude, 37.33, accuracy: 0.000_001)
        XCTAssertEqual(anonymized.longitude, -122.03, accuracy: 0.000_001)
    }
}
