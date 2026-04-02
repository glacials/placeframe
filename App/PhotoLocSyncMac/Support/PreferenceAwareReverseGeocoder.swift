import PhotoLocSyncAdapters
import PhotoLocSyncCore

actor PreferenceAwareReverseGeocoder: ReverseGeocoding {
    private let settings: LocationLabelingSettings
    private let offlineGeocoder: any ReverseGeocoding
    private let appleGeocoder: any ReverseGeocoding

    init(
        settings: LocationLabelingSettings,
        offlineGeocoder: any ReverseGeocoding = OfflineReverseGeocoder(),
        appleGeocoder: any ReverseGeocoding = CLGeocoderAdapter()
    ) {
        self.settings = settings
        self.offlineGeocoder = offlineGeocoder
        self.appleGeocoder = appleGeocoder
    }

    func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation {
        switch await settings.effectiveChoice() {
        case .localCoordinatesOnly:
            return await offlineGeocoder.resolveLocation(for: coordinate)
        case .allowAppleGeocoding:
            return await appleGeocoder.resolveLocation(for: coordinate)
        }
    }
}
