import Foundation

public enum TimelineSegmentKind: String, Codable, Sendable {
    case visit
    case activity
    case timelinePath
    case memory
}

public struct TimelineSegment: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: TimelineSegmentKind
    public let startTime: Date
    public let endTime: Date
    public let startCoordinate: GeoCoordinate?
    public let endCoordinate: GeoCoordinate?
    public let centerCoordinate: GeoCoordinate?

    public init(
        id: String = UUID().uuidString,
        kind: TimelineSegmentKind,
        startTime: Date,
        endTime: Date,
        startCoordinate: GeoCoordinate? = nil,
        endCoordinate: GeoCoordinate? = nil,
        centerCoordinate: GeoCoordinate? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startTime = startTime
        self.endTime = endTime
        self.startCoordinate = startCoordinate
        self.endCoordinate = endCoordinate
        self.centerCoordinate = centerCoordinate
    }

    public func contains(_ date: Date) -> Bool {
        startTime <= date && date <= endTime
    }
}
