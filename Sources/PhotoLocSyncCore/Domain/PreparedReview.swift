import Foundation

public struct PreparedReview: Sendable {
    public let timeline: ImportedTimeline
    public let candidateAssets: [PhotoAsset]
    public let items: [ReviewItem]
    public let summary: ReviewSummary
    public let captureTimeOffset: TimeInterval
    public let captureTimeOffsetAnalysis: CaptureTimeOffsetAnalysis?

    public init(
        timeline: ImportedTimeline,
        candidateAssets: [PhotoAsset],
        items: [ReviewItem],
        summary: ReviewSummary,
        captureTimeOffset: TimeInterval,
        captureTimeOffsetAnalysis: CaptureTimeOffsetAnalysis?
    ) {
        self.timeline = timeline
        self.candidateAssets = candidateAssets
        self.items = items
        self.summary = summary
        self.captureTimeOffset = captureTimeOffset
        self.captureTimeOffsetAnalysis = captureTimeOffsetAnalysis
    }
}
