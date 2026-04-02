import XCTest
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

private actor StubReverseGeocoder: ReverseGeocoding {
    let resolvedLocation: ResolvedLocation

    init(resolvedLocation: ResolvedLocation) {
        self.resolvedLocation = resolvedLocation
    }

    func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation {
        resolvedLocation
    }
}

@MainActor
final class LocationLabelingSettingsTests: XCTestCase {
    func testSettingsPersistExplicitChoiceAcrossInstances() {
        let suiteName = "LocationLabelingSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated test defaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstSettings = LocationLabelingSettings(suiteName: suiteName)
        XCTAssertTrue(firstSettings.needsExplicitChoice)
        XCTAssertNil(firstSettings.choice)

        firstSettings.setChoice(.allowAppleGeocoding)

        let secondSettings = LocationLabelingSettings(suiteName: suiteName)
        XCTAssertFalse(secondSettings.needsExplicitChoice)
        XCTAssertEqual(secondSettings.choice, .allowAppleGeocoding)
    }

    func testPreferenceAwareReverseGeocoderDefaultsToOfflineWhenUnset() async {
        let suiteName = "LocationLabelingSettingsTests.\(UUID().uuidString)"
        let coordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        let settings = LocationLabelingSettings(suiteName: suiteName)
        let offline = StubReverseGeocoder(
            resolvedLocation: ResolvedLocation(
                options: [
                    LocationOption(precision: .exact, coordinate: coordinate, label: "35.6895, 139.6917")
                ]
            )
        )
        let online = StubReverseGeocoder(
            resolvedLocation: ResolvedLocation(
                options: [
                    LocationOption(precision: .exact, coordinate: coordinate, label: "Tokyo, Japan")
                ]
            )
        )
        let geocoder = PreferenceAwareReverseGeocoder(
            settings: settings,
            offlineGeocoder: offline,
            appleGeocoder: online
        )

        let resolved = await geocoder.resolveLocation(for: coordinate)

        XCTAssertEqual(resolved.defaultOption?.label, "35.6895, 139.6917")
    }

    func testPreferenceAwareReverseGeocoderUsesAppleGeocoderWhenEnabled() async {
        let suiteName = "LocationLabelingSettingsTests.\(UUID().uuidString)"
        let coordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        let settings = LocationLabelingSettings(suiteName: suiteName)
        settings.setChoice(.allowAppleGeocoding)
        let offline = StubReverseGeocoder(
            resolvedLocation: ResolvedLocation(
                options: [
                    LocationOption(precision: .exact, coordinate: coordinate, label: "35.6895, 139.6917")
                ]
            )
        )
        let online = StubReverseGeocoder(
            resolvedLocation: ResolvedLocation(
                options: [
                    LocationOption(precision: .exact, coordinate: coordinate, label: "Tokyo, Japan")
                ]
            )
        )
        let geocoder = PreferenceAwareReverseGeocoder(
            settings: settings,
            offlineGeocoder: offline,
            appleGeocoder: online
        )

        let resolved = await geocoder.resolveLocation(for: coordinate)

        XCTAssertEqual(resolved.defaultOption?.label, "Tokyo, Japan")
    }
}
