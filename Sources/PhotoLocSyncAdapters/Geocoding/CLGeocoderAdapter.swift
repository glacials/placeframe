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

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let resolvedLocation: ResolvedLocation
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                resolvedLocation = await makeResolvedLocation(for: coordinate, placemark: placemark)
            } else {
                resolvedLocation = fallbackLocation(for: coordinate)
            }
        } catch {
            resolvedLocation = fallbackLocation(for: coordinate)
        }

        await cache.insert(resolvedLocation, for: coordinate)
        return resolvedLocation
    }

    private func makeResolvedLocation(for coordinate: GeoCoordinate, placemark: CLPlacemark) async -> ResolvedLocation {
        var options: [LocationOption] = []
        options.append(
            LocationOption(
                precision: .exact,
                coordinate: coordinate,
                label: exactLabel(for: placemark, fallbackCoordinate: coordinate)
            )
        )

        if let cityOption = await broaderLocationOption(
            precision: .city,
            labelComponents: [placemark.locality, placemark.administrativeArea, placemark.country]
        ) {
            options.append(cityOption)
        }

        if let regionOption = await broaderLocationOption(
            precision: .region,
            labelComponents: [placemark.administrativeArea ?? placemark.subAdministrativeArea, placemark.country]
        ) {
            options.append(regionOption)
        }

        if let countryOption = await broaderLocationOption(
            precision: .country,
            labelComponents: [placemark.country]
        ) {
            options.append(countryOption)
        }

        return ResolvedLocation(options: uniqueOptions(from: options))
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

    private func broaderLocationOption(
        precision: LocationPrecision,
        labelComponents: [String?]
    ) async -> LocationOption? {
        let label = joinedLabel(from: labelComponents)
        guard !label.isEmpty,
              let coordinate = await coordinate(forQuery: label) else {
            return nil
        }

        return LocationOption(precision: precision, coordinate: coordinate, label: label)
    }

    private func coordinate(forQuery query: String) async -> GeoCoordinate? {
        if let cached = await cache.queryValue(for: query) {
            return cached
        }

        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            guard let coordinate = placemarks.first?.location?.coordinate.asGeoCoordinate else {
                return nil
            }

            await cache.insertQueryValue(coordinate, for: query)
            return coordinate
        } catch {
            return nil
        }
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

    private func uniqueOptions(from options: [LocationOption]) -> [LocationOption] {
        var seenLabels: Set<String> = []
        var seenCoordinates: Set<GeoCoordinate> = []
        var unique: [LocationOption] = []

        for option in options.sorted(by: { $0.precision.rawValue < $1.precision.rawValue }) {
            let labelKey = option.label.lowercased()
            guard seenLabels.insert(labelKey).inserted,
                  seenCoordinates.insert(option.coordinate).inserted else {
                continue
            }

            unique.append(option)
        }

        return unique
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
