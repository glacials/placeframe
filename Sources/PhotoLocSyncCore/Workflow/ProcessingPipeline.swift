import Foundation

public final class ProcessingPipeline: Sendable {
    private let importer: any TimelineImporting
    private let reader: any PhotoLibraryReading
    private let geocoder: any ReverseGeocoding
    private let matcher: TimelineMatcher
    private let labelFormatter: LocationLabelFormatter
    private let policy: MatchPolicy

    public init(
        importer: any TimelineImporting,
        reader: any PhotoLibraryReading,
        geocoder: any ReverseGeocoding,
        matcher: TimelineMatcher = TimelineMatcher(),
        labelFormatter: LocationLabelFormatter = LocationLabelFormatter(),
        policy: MatchPolicy = MatchPolicy()
    ) {
        self.importer = importer
        self.reader = reader
        self.geocoder = geocoder
        self.matcher = matcher
        self.labelFormatter = labelFormatter
        self.policy = policy
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

        onStageChange(.matchingLocations)
        let matches = matcher.match(assets: assets, timeline: timeline)

        onStageChange(.reverseGeocodingPlaces)
        let items = await buildReviewItems(from: matches)

        onStageChange(.preparingReview)
        let summary = ReviewSummary(
            totalAssets: items.count,
            autoSuggested: matches.filter { $0.disposition == .autoSuggested }.count,
            ambiguous: matches.filter { $0.disposition == .ambiguous }.count,
            unmatched: matches.filter { $0.disposition == .unmatched }.count
        )

        return PreparedReview(timeline: timeline, items: items, summary: summary)
    }

    private func buildReviewItems(from matches: [MatchCandidate]) async -> [ReviewItem] {
        var built: [ReviewItem] = []
        built.reserveCapacity(matches.count)

        for match in matches {
            guard match.disposition != .unmatched, let point = match.point else {
                continue
            }

            let label = await geocoder.label(for: point.coordinate)
            let finalLabel = label.isEmpty ? labelFormatter.string(for: point.coordinate) : label
            let decision = MatchDecision(
                assetID: match.asset.id,
                captureDate: match.asset.creationDate,
                coordinate: point.coordinate,
                label: finalLabel,
                confidence: match.confidence
            )
            built.append(
                ReviewItem(
                    asset: match.asset,
                    proposedCoordinate: point.coordinate,
                    locationLabel: finalLabel,
                    confidence: match.confidence,
                    timeDelta: match.timeDelta,
                    disposition: match.disposition,
                    suggestedDecision: match.disposition == .unmatched ? nil : decision
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
