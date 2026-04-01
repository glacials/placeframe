import Foundation

public struct PreparedReview: Sendable {
    public let timeline: ImportedTimeline
    public let items: [ReviewItem]
    public let summary: ReviewSummary

    public init(timeline: ImportedTimeline, items: [ReviewItem], summary: ReviewSummary) {
        self.timeline = timeline
        self.items = items
        self.summary = summary
    }
}
