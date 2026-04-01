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

    public init(
        asset: PhotoAsset,
        proposedCoordinate: GeoCoordinate?,
        locationLabel: String,
        confidence: MatchConfidence,
        timeDelta: TimeInterval?,
        disposition: MatchDisposition,
        suggestedDecision: MatchDecision?
    ) {
        self.id = asset.id
        self.asset = asset
        self.proposedCoordinate = proposedCoordinate
        self.locationLabel = locationLabel
        self.confidence = confidence
        self.timeDelta = timeDelta
        self.disposition = disposition
        self.suggestedDecision = suggestedDecision
    }
}
