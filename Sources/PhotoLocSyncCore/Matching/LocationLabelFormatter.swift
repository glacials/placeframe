import Foundation

public struct LocationLabelFormatter: Sendable {
    public init() {}

    public func string(for coordinate: GeoCoordinate) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}
