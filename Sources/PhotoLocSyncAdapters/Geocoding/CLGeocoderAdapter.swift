import CoreLocation
import Foundation
import PhotoLocSyncCore

public actor CLGeocoderAdapter: ReverseGeocoding {
    private let cache: LabelCache
    private let formatter = LocationLabelFormatter()

    public init(cache: LabelCache = LabelCache()) {
        self.cache = cache
    }

    public func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation {
        if let cached = await cache.value(for: coordinate) {
            return cached
        }

        let requestCoordinate = Self.anonymizedCoordinate(for: coordinate)
        let location = CLLocation(latitude: requestCoordinate.latitude, longitude: requestCoordinate.longitude)
        let resolvedLocation: ResolvedLocation
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                resolvedLocation = makeResolvedLocation(for: coordinate, placemark: placemark)
            } else {
                resolvedLocation = fallbackLocation(for: coordinate)
            }
        } catch {
            resolvedLocation = fallbackLocation(for: coordinate)
        }

        await cache.insert(resolvedLocation, for: coordinate)
        return resolvedLocation
    }

    static func anonymizedCoordinate(for coordinate: GeoCoordinate) -> GeoCoordinate {
        GeoCoordinate(
            latitude: round(coordinate.latitude * 100) / 100,
            longitude: round(coordinate.longitude * 100) / 100
        )
    }

    private func makeResolvedLocation(for coordinate: GeoCoordinate, placemark: CLPlacemark) -> ResolvedLocation {
        ResolvedLocation(
            options: [
                LocationOption(
                    precision: .exact,
                    coordinate: coordinate,
                    label: exactLabel(for: placemark, fallbackCoordinate: coordinate)
                )
            ]
        )
    }

    private func fallbackLocation(for coordinate: GeoCoordinate) -> ResolvedLocation {
        ResolvedLocation(
            options: [
                LocationOption(
                    precision: .exact,
                    coordinate: coordinate,
                    label: formatter.string(for: coordinate)
                )
            ]
        )
    }

    private func exactLabel(for placemark: CLPlacemark, fallbackCoordinate: GeoCoordinate) -> String {
        let label = joinedLabel(
            from: [
                placemark.name ?? exactStreetAddress(for: placemark),
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
        )
        return label.isEmpty ? formatter.string(for: fallbackCoordinate) : label
    }

    private func exactStreetAddress(for placemark: CLPlacemark) -> String? {
        let address = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap(normalizedComponent(_:))
            .joined(separator: " ")
        return address.isEmpty ? nil : address
    }

    private func joinedLabel(from components: [String?]) -> String {
        var seen: Set<String> = []
        var result: [String] = []

        for component in components.compactMap(normalizedComponent(_:)) {
            let key = component.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }
            result.append(component)
        }

        return result.joined(separator: ", ")
    }

    private func normalizedComponent(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension CLLocationCoordinate2D {
    var asGeoCoordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}
