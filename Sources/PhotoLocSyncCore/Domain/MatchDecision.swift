import Foundation

public struct MatchDecision: Identifiable, Hashable, Sendable {
    public let id: String
    public let assetID: String
    public let captureDate: Date
    public let coordinate: GeoCoordinate
    public let label: String
    public let confidence: MatchConfidence

    public init(assetID: String, captureDate: Date, coordinate: GeoCoordinate, label: String, confidence: MatchConfidence) {
        self.id = assetID
        self.assetID = assetID
        self.captureDate = captureDate
        self.coordinate = coordinate
        self.label = label
        self.confidence = confidence
    }
}
