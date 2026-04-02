import Foundation

public final class SyncCoordinator: Sendable {
    private let pipeline: ProcessingPipeline
    private let writer: any PhotoLibraryWriting

    public init(pipeline: ProcessingPipeline, writer: any PhotoLibraryWriting) {
        self.pipeline = pipeline
        self.writer = writer
    }

    public func prepareReview(
        from data: Data,
        onStageChange: @escaping @Sendable (ProcessingStage) -> Void
    ) async throws -> PreparedReview {
        try await pipeline.prepareReview(from: data, onStageChange: onStageChange)
    }

    public func prepareReview(
        timeline: ImportedTimeline,
        assets: [PhotoAsset],
        captureTimeOffset: TimeInterval = 0
    ) async -> PreparedReview {
        await pipeline.prepareReview(
            timeline: timeline,
            assets: assets,
            captureTimeOffset: captureTimeOffset
        )
    }

    public func prepareReview(
        timeline: ImportedTimeline,
        assets: [PhotoAsset],
        captureTimeOffsetsByDayStart: [Date: TimeInterval]
    ) async -> PreparedReview {
        await pipeline.prepareReview(
            timeline: timeline,
            assets: assets,
            captureTimeOffsetsByDayStart: captureTimeOffsetsByDayStart
        )
    }

    public func apply(_ decisions: [MatchDecision]) async throws -> ApplySummary {
        let results = try await writer.apply(decisions)
        return ApplySummary(
            updated: results.filter { $0.outcome == .updated }.count,
            skipped: results.filter { $0.outcome == .skipped }.count,
            failed: results.filter { $0.outcome == .failed }.count,
            failures: results.filter { $0.outcome == .failed }
        )
    }

    public func deleteAsset(withID assetID: String) async throws {
        try await writer.deleteAsset(withID: assetID)
    }
}
