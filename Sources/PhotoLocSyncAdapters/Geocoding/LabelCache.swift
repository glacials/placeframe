import Foundation
import PhotoLocSyncCore

public actor LabelCache {
    private var storage: [GeoCoordinate: ResolvedLocation] = [:]
    private var queryStorage: [String: GeoCoordinate] = [:]

    public init() {}

    public func value(for coordinate: GeoCoordinate) -> ResolvedLocation? {
        storage[coordinate]
    }

    public func insert(_ resolvedLocation: ResolvedLocation, for coordinate: GeoCoordinate) {
        storage[coordinate] = resolvedLocation
    }

    public func queryValue(for query: String) -> GeoCoordinate? {
        queryStorage[query]
    }

    public func insertQueryValue(_ coordinate: GeoCoordinate, for query: String) {
        queryStorage[query] = coordinate
    }
}
