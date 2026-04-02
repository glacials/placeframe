import Foundation

public struct TimelineMatcher: Sendable {
    private let scorer: MatchScorer
    private let policy: MatchPolicy

    public init(scorer: MatchScorer = MatchScorer(), policy: MatchPolicy = MatchPolicy()) {
        self.scorer = scorer
        self.policy = policy
    }

    public func match(
        assets: [PhotoAsset],
        timeline: ImportedTimeline,
        captureTimeOffset: TimeInterval = 0
    ) -> [MatchCandidate] {
        let sortedPoints = timeline.points.sorted { $0.timestamp < $1.timestamp }
        let visitSegments = timeline.segments.filter { $0.kind == .visit && $0.centerCoordinate != nil }

        return assets.map { asset in
            let adjustedCaptureDate = asset.creationDate.addingTimeInterval(captureTimeOffset)
            let nearestPoint = nearestPoint(to: adjustedCaptureDate, points: sortedPoints)
            let containingVisit = visitSegments.first { $0.contains(adjustedCaptureDate) }

            guard let point = nearestPoint else {
                return MatchCandidate(asset: asset, point: nil, timeDelta: nil, confidence: .rejected, disposition: .unmatched)
            }

            if containingVisit == nil, liesInCoverageGap(adjustedCaptureDate, points: sortedPoints) {
                return MatchCandidate(asset: asset, point: nil, timeDelta: nil, confidence: .rejected, disposition: .unmatched)
            }

            let delta = adjustedCaptureDate.timeIntervalSince(point.timestamp)
            let insideVisit = containingVisit != nil
            let scored = scorer.score(delta: delta, insideStationaryVisit: insideVisit, policy: policy)

            if let visit = containingVisit, let center = visit.centerCoordinate, abs(delta) > policy.maybeThreshold {
                let midpoint = visit.startTime.addingTimeInterval(visit.endTime.timeIntervalSince(visit.startTime) / 2)
                let visitPoint = TimelinePoint(id: "\(visit.id)-fallback", timestamp: midpoint, coordinate: center, source: .visit, semanticLabel: "Visit")
                let visitDelta = adjustedCaptureDate.timeIntervalSince(midpoint)
                let visitScore = scorer.score(delta: visitDelta, insideStationaryVisit: true, policy: policy)
                return MatchCandidate(asset: asset, point: visitPoint, timeDelta: visitDelta, confidence: visitScore.0, disposition: visitScore.1)
            }

            return MatchCandidate(asset: asset, point: point, timeDelta: delta, confidence: scored.0, disposition: scored.1)
        }
    }

    private func nearestPoint(to target: Date, points: [TimelinePoint]) -> TimelinePoint? {
        guard !points.isEmpty else { return nil }

        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].timestamp < target {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let candidateIndices = [max(0, low - 1), low, min(points.count - 1, low + 1)]
        return candidateIndices
            .map { points[$0] }
            .min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }
    }

    private func liesInCoverageGap(_ target: Date, points: [TimelinePoint]) -> Bool {
        guard points.count >= 2 else { return false }

        var low = 0
        var high = points.count
        while low < high {
            let mid = (low + high) / 2
            if points[mid].timestamp < target {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let previous = low > 0 ? points[low - 1] : nil
        let next = low < points.count ? points[low] : nil

        if let previous, let next {
            let surroundingGap = next.timestamp.timeIntervalSince(previous.timestamp)
            if surroundingGap > policy.coverageGapThreshold {
                return true
            }
        }

        if previous == nil, let next {
            return abs(next.timestamp.timeIntervalSince(target)) > policy.coverageGapThreshold
        }

        if next == nil, let previous {
            return abs(target.timeIntervalSince(previous.timestamp)) > policy.coverageGapThreshold
        }

        return false
    }
}
