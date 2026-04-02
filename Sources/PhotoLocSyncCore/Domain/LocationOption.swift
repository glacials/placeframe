import Foundation

public enum LocationPrecision: Int, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case exact
    case city
    case region
    case country

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .exact: "Specific match"
        case .city: "City"
        case .region: "State or region"
        case .country: "Country"
        }
    }
}

public struct LocationOption: Identifiable, Hashable, Sendable {
    public let precision: LocationPrecision
    public let coordinate: GeoCoordinate
    public let label: String

    public var id: LocationPrecision { precision }

    public init(precision: LocationPrecision, coordinate: GeoCoordinate, label: String) {
        self.precision = precision
        self.coordinate = coordinate
        self.label = label
    }
}

public struct ResolvedLocation: Hashable, Sendable {
    public let options: [LocationOption]

    public init(options: [LocationOption]) {
        self.options = options.sorted { $0.precision.rawValue < $1.precision.rawValue }
    }

    public var defaultOption: LocationOption? {
        options.first
    }

    public func option(for precision: LocationPrecision) -> LocationOption? {
        options.first { $0.precision == precision }
    }
}
