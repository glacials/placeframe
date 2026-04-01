import Foundation

public protocol ReverseGeocoding: Sendable {
    func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation
}
