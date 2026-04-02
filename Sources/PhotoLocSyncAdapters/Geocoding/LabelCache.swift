import Foundation
import PhotoLocSyncCore

public actor LabelCache {
    private var storage: [GeoCoordinate: ResolvedLocation] = [:]

    public init() {}

    public func value(for coordinate: GeoCoordinate) -> ResolvedLocation? {
        storage[coordinate]
    }

    public func insert(_ resolvedLocation: ResolvedLocation, for coordinate: GeoCoordinate) {
        storage[coordinate] = resolvedLocation
    }
}
