import Foundation
import PhotoLocSyncCore

public actor LabelCache {
    private var storage: [GeoCoordinate: String] = [:]

    public init() {}

    public func value(for coordinate: GeoCoordinate) -> String? {
        storage[coordinate]
    }

    public func insert(_ label: String, for coordinate: GeoCoordinate) {
        storage[coordinate] = label
    }
}
