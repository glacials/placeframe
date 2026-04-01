import Foundation

public protocol ReverseGeocoding: Sendable {
    func label(for coordinate: GeoCoordinate) async -> String
}
