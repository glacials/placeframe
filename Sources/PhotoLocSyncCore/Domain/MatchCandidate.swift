import Foundation

public enum MatchConfidence: String, Codable, CaseIterable, Sendable {
    case excellent
    case acceptable
    case maybe
    case rejected
}

public enum MatchDisposition: String, Codable, CaseIterable, Sendable {
    case autoSuggested
    case ambiguous
    case unmatched
}

public struct MatchCandidate: Identifiable, Hashable, Sendable {
    public let id: String
    public let asset: PhotoAsset
    public let point: TimelinePoint?
    public let timeDelta: TimeInterval?
    public let confidence: MatchConfidence
    public let disposition: MatchDisposition

    public init(
        asset: PhotoAsset,
        point: TimelinePoint?,
        timeDelta: TimeInterval?,
        confidence: MatchConfidence,
        disposition: MatchDisposition
    ) {
        self.id = asset.id
        self.asset = asset
        self.point = point
        self.timeDelta = timeDelta
        self.confidence = confidence
        self.disposition = disposition
    }
}
