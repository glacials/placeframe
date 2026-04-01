import Foundation

public enum TimelinePointSource: String, Codable, Sendable {
    case visit
    case timelinePath
    case activityStart
    case activityEnd
}

public struct TimelinePoint: Identifiable, Hashable, Sendable {
    public let id: String
    public let timestamp: Date
    public let coordinate: GeoCoordinate
    public let source: TimelinePointSource
    public let semanticLabel: String?

    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        coordinate: GeoCoordinate,
        source: TimelinePointSource,
        semanticLabel: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.source = source
        self.semanticLabel = semanticLabel
    }
}
