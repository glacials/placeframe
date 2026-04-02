import Foundation
import PhotoLocSyncCore

public actor OfflineReverseGeocoder: ReverseGeocoding {
    private let formatter = LocationLabelFormatter()

    public init() {}

    public func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation {
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
}
