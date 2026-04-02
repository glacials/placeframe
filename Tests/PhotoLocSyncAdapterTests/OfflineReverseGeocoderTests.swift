import XCTest
@testable import PhotoLocSyncAdapters
@testable import PhotoLocSyncCore

final class OfflineReverseGeocoderTests: XCTestCase {
    func testResolveLocationReturnsOnlyExactFormattedCoordinate() async {
        let geocoder = OfflineReverseGeocoder()
        let coordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)

        let resolved = await geocoder.resolveLocation(for: coordinate)

        XCTAssertEqual(resolved.options.count, 1)
        XCTAssertEqual(resolved.options[0].precision, .exact)
        XCTAssertEqual(resolved.options[0].coordinate, coordinate)
        XCTAssertEqual(resolved.options[0].label, "35.6895, 139.6917")
    }
}
