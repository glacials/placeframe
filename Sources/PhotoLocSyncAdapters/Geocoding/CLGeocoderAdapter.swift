import CoreLocation
import Foundation
import PhotoLocSyncCore

public actor CLGeocoderAdapter: ReverseGeocoding {
    private let geocoder = CLGeocoder()
    private let cache: LabelCache
    private let formatter = LocationLabelFormatter()

    public init(cache: LabelCache = LabelCache()) {
        self.cache = cache
    }

    public func label(for coordinate: GeoCoordinate) async -> String {
        if let cached = await cache.value(for: coordinate) {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let components = [placemark?.name, placemark?.locality, placemark?.administrativeArea, placemark?.country]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            let label = components.isEmpty ? formatter.string(for: coordinate) : components.joined(separator: ", ")
            await cache.insert(label, for: coordinate)
            return label
        } catch {
            let fallback = formatter.string(for: coordinate)
            await cache.insert(fallback, for: coordinate)
            return fallback
        }
    }
}
