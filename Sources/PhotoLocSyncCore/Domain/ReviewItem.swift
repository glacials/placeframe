import Foundation

public struct ReviewItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let asset: PhotoAsset
    public let proposedCoordinate: GeoCoordinate?
    public let locationLabel: String
    public let confidence: MatchConfidence
    public let timeDelta: TimeInterval?
    public let disposition: MatchDisposition
    public let suggestedDecision: MatchDecision?
    public let availableLocationOptions: [LocationOption]

    public init(
        asset: PhotoAsset,
        proposedCoordinate: GeoCoordinate?,
        locationLabel: String,
        confidence: MatchConfidence,
        timeDelta: TimeInterval?,
        disposition: MatchDisposition,
        suggestedDecision: MatchDecision?,
        availableLocationOptions: [LocationOption] = []
    ) {
        self.id = asset.id
        self.asset = asset
        self.proposedCoordinate = proposedCoordinate
        self.locationLabel = locationLabel
        self.confidence = confidence
        self.timeDelta = timeDelta
        self.disposition = disposition
        self.suggestedDecision = suggestedDecision
        if availableLocationOptions.isEmpty,
           let proposedCoordinate {
            self.availableLocationOptions = [
                LocationOption(
                    precision: suggestedDecision?.precision ?? .exact,
                    coordinate: proposedCoordinate,
                    label: locationLabel
                )
            ]
        } else {
            self.availableLocationOptions = availableLocationOptions.sorted {
                $0.precision.rawValue < $1.precision.rawValue
            }
        }
    }

    public var selectedPrecision: LocationPrecision? {
        suggestedDecision?.precision ?? availableLocationOptions.first?.precision
    }

    public func locationOption(for precision: LocationPrecision) -> LocationOption? {
        availableLocationOptions.first { $0.precision == precision }
    }
}
