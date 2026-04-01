import Foundation

public struct ImportedTimeline: Hashable, Sendable {
    public let range: ClosedRange<Date>
    public let points: [TimelinePoint]
    public let segments: [TimelineSegment]
    public let recordTypeCounts: [String: Int]

    public init(range: ClosedRange<Date>, points: [TimelinePoint], segments: [TimelineSegment], recordTypeCounts: [String: Int]) {
        self.range = range
        self.points = points
        self.segments = segments
        self.recordTypeCounts = recordTypeCounts
    }
}
