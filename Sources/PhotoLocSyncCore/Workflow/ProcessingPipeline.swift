import Foundation

public final class ProcessingPipeline: Sendable {
    private let importer: any TimelineImporting
    private let reader: any PhotoLibraryReading
    private let geocoder: any ReverseGeocoding
    private let matcher: TimelineMatcher
    private let labelFormatter: LocationLabelFormatter
    private let policy: MatchPolicy
    private let captureTimeOffsetAnalyzer: CaptureTimeOffsetAnalyzer

    public init(
        importer: any TimelineImporting,
        reader: any PhotoLibraryReading,
        geocoder: any ReverseGeocoding,
        matcher: TimelineMatcher = TimelineMatcher(),
        labelFormatter: LocationLabelFormatter = LocationLabelFormatter(),
        policy: MatchPolicy = MatchPolicy(),
        captureTimeOffsetAnalyzer: CaptureTimeOffsetAnalyzer = CaptureTimeOffsetAnalyzer()
    ) {
        self.importer = importer
        self.reader = reader
        self.geocoder = geocoder
        self.matcher = matcher
        self.labelFormatter = labelFormatter
        self.policy = policy
        self.captureTimeOffsetAnalyzer = captureTimeOffsetAnalyzer
    }

    public func prepareReview(
        from data: Data,
        onStageChange: @escaping @Sendable (ProcessingStage) -> Void
    ) async throws -> PreparedReview {
        onStageChange(.readingTimeline)
        let timeline = try importer.loadTimeline(from: data)

        onStageChange(.scanningPhotosLibrary)
        let candidateRange = timeline.range.expanded(by: policy.candidatePadding)
        let assets = try await reader.fetchCandidateAssets(in: candidateRange)

        return await prepareReview(
            timeline: timeline,
            assets: assets,
            captureTimeOffset: 0,
            onStageChange: onStageChange
        )
    }

    public func prepareReview(
        timeline: ImportedTimeline,
        assets: [PhotoAsset],
        captureTimeOffset: TimeInterval = 0
    ) async -> PreparedReview {
        await prepareReview(
            timeline: timeline,
            assets: assets,
            captureTimeOffset: captureTimeOffset,
            onStageChange: nil
        )
    }

    private func prepareReview(
        timeline: ImportedTimeline,
        assets: [PhotoAsset],
        captureTimeOffset: TimeInterval,
        onStageChange: (@Sendable (ProcessingStage) -> Void)?
    ) async -> PreparedReview {
        onStageChange?(.matchingLocations)
        let matches = matcher.match(assets: assets, timeline: timeline, captureTimeOffset: captureTimeOffset)
        let captureTimeOffsetAnalysis = captureTimeOffsetAnalyzer.analyze(
            timeline: timeline,
            assets: assets,
            currentOffset: captureTimeOffset
        )

        onStageChange?(.reverseGeocodingPlaces)
        let items = await buildReviewItems(from: matches)

        onStageChange?(.preparingReview)
        let summary = ReviewSummary(
            totalAssets: items.count,
            autoSuggested: matches.filter { $0.disposition == .autoSuggested }.count,
            ambiguous: matches.filter { $0.disposition == .ambiguous }.count,
            unmatched: matches.filter { $0.disposition == .unmatched }.count
        )

        return PreparedReview(
            timeline: timeline,
            candidateAssets: assets,
            items: items,
            summary: summary,
            captureTimeOffset: captureTimeOffset,
            captureTimeOffsetAnalysis: captureTimeOffsetAnalysis
        )
    }

    private func buildReviewItems(from matches: [MatchCandidate]) async -> [ReviewItem] {
        var built: [ReviewItem] = []
        built.reserveCapacity(matches.count)

        for match in matches {
            guard match.disposition != .unmatched, let point = match.point else {
                continue
            }

            let resolvedLocation = await geocoder.resolveLocation(for: point.coordinate)
            let defaultOption = resolvedLocation.defaultOption ?? LocationOption(
                precision: .exact,
                coordinate: point.coordinate,
                label: labelFormatter.string(for: point.coordinate)
            )
            let decision = MatchDecision(
                assetID: match.asset.id,
                captureDate: match.asset.creationDate,
                coordinate: defaultOption.coordinate,
                label: defaultOption.label,
                confidence: match.confidence,
                precision: defaultOption.precision
            )
            built.append(
                ReviewItem(
                    asset: match.asset,
                    proposedCoordinate: defaultOption.coordinate,
                    locationLabel: defaultOption.label,
                    confidence: match.confidence,
                    timeDelta: match.timeDelta,
                    disposition: match.disposition,
                    suggestedDecision: match.disposition == .unmatched ? nil : decision,
                    availableLocationOptions: resolvedLocation.options
                )
            )
        }

        return built.sorted { $0.asset.creationDate < $1.asset.creationDate }
    }
}

private extension ClosedRange where Bound == Date {
    func expanded(by seconds: TimeInterval) -> ClosedRange<Date> {
        lowerBound.addingTimeInterval(-seconds)...upperBound.addingTimeInterval(seconds)
    }
}
