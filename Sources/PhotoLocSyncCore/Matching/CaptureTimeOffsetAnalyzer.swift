import Foundation

public struct CaptureTimeOffsetAnalyzer: Sendable {
    private let matcher: TimelineMatcher
    private let candidateOffsets: [TimeInterval]
    private let selectableOffsets: [TimeInterval]
    private let minimumAssetCount: Int
    private let displayedOptionCount: Int

    public init(
        matcher: TimelineMatcher = TimelineMatcher(),
        candidateOffsets: [TimeInterval] = Array(-14...14).map { Double($0) * 60 * 60 },
        selectableOffsets: [TimeInterval] = stride(from: -14 * 60 * 60, through: 14 * 60 * 60, by: 15 * 60).map(Double.init),
        minimumAssetCount: Int = 1,
        displayedOptionCount: Int = 3
    ) {
        self.matcher = matcher
        self.candidateOffsets = candidateOffsets
        self.selectableOffsets = selectableOffsets
        self.minimumAssetCount = minimumAssetCount
        self.displayedOptionCount = displayedOptionCount
    }

    public func analyze(
        timeline: ImportedTimeline,
        assets: [PhotoAsset],
        currentOffset: TimeInterval = 0
    ) -> CaptureTimeOffsetAnalysis? {
        guard assets.count >= minimumAssetCount else { return nil }

        let offsets = Set(selectableOffsets + [currentOffset]).sorted()
        let visitSegments = timeline.segments.filter { $0.kind == .visit }
        let evaluated = offsets.map { offset in
            let matches = matcher.match(assets: assets, timeline: timeline, captureTimeOffset: offset)
            let metrics = metrics(for: matches, visitSegments: visitSegments, captureTimeOffset: offset)
            return CaptureTimeOffsetOption(offset: offset, matches: matches, metrics: metrics)
        }
        guard let currentOption = evaluated.first(where: { $0.offset == currentOffset }) else {
            return nil
        }

        let ranked = Set(candidateOffsets + [currentOffset]).sorted().compactMap { offset in
            evaluated.first { $0.offset == offset }
        }
        .sorted(by: isBetter)
        let recommendedOffset = recommendedOffset(from: ranked, currentOption: currentOption, totalAssets: assets.count)
        let options = displayedOptions(from: ranked, currentOption: currentOption, recommendedOffset: recommendedOffset)

        return CaptureTimeOffsetAnalysis(
            currentOffset: currentOffset,
            recommendedOffset: recommendedOffset,
            options: options,
            allOptions: evaluated
        )
    }

    private func metrics(
        for matches: [MatchCandidate],
        visitSegments: [TimelineSegment],
        captureTimeOffset: TimeInterval
    ) -> CaptureTimeOffsetMetrics {
        let absoluteDeltas = matches.compactMap(\.timeDelta).map(abs).sorted()
        let visitContained = matches.filter { match in
            let adjustedCaptureDate = match.asset.creationDate.addingTimeInterval(captureTimeOffset)
            return visitSegments.contains { $0.contains(adjustedCaptureDate) }
        }.count

        return CaptureTimeOffsetMetrics(
            totalAssets: matches.count,
            autoSuggested: matches.filter { $0.disposition == .autoSuggested }.count,
            ambiguous: matches.filter { $0.disposition == .ambiguous }.count,
            unmatched: matches.filter { $0.disposition == .unmatched }.count,
            visitContained: visitContained,
            medianAbsoluteTimeDelta: median(from: absoluteDeltas)
        )
    }

    private func median(from sortedValues: [TimeInterval]) -> TimeInterval? {
        guard !sortedValues.isEmpty else { return nil }

        let middleIndex = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2
        }
        return sortedValues[middleIndex]
    }

    private func isBetter(_ lhs: CaptureTimeOffsetOption, _ rhs: CaptureTimeOffsetOption) -> Bool {
        if lhs.metrics.visitContained != rhs.metrics.visitContained {
            return lhs.metrics.visitContained > rhs.metrics.visitContained
        }
        if lhs.metrics.matched != rhs.metrics.matched {
            return lhs.metrics.matched > rhs.metrics.matched
        }
        if lhs.metrics.autoSuggested != rhs.metrics.autoSuggested {
            return lhs.metrics.autoSuggested > rhs.metrics.autoSuggested
        }
        if lhs.metrics.unmatched != rhs.metrics.unmatched {
            return lhs.metrics.unmatched < rhs.metrics.unmatched
        }

        switch compareMedian(lhs.metrics.medianAbsoluteTimeDelta, rhs.metrics.medianAbsoluteTimeDelta) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            break
        }

        if abs(lhs.offset) != abs(rhs.offset) {
            return abs(lhs.offset) < abs(rhs.offset)
        }
        return lhs.offset < rhs.offset
    }

    private func compareMedian(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (.some, .none):
            return .orderedAscending
        case (.none, .some):
            return .orderedDescending
        case (.none, .none):
            return .orderedSame
        }
    }

    private func recommendedOffset(
        from ranked: [CaptureTimeOffsetOption],
        currentOption: CaptureTimeOffsetOption,
        totalAssets: Int
    ) -> TimeInterval? {
        guard let best = ranked.first, best.offset != currentOption.offset else {
            return nil
        }

        let matchedGain = best.metrics.matched - currentOption.metrics.matched
        let visitGain = best.metrics.visitContained - currentOption.metrics.visitContained
        let autoGain = best.metrics.autoSuggested - currentOption.metrics.autoSuggested
        let minimumMatchedCount = max(4, Int(ceil(Double(totalAssets) * 0.55)))
        let minimumGain = max(3, totalAssets / 4)
        let minimumVisitGain = max(2, totalAssets / 5)

        guard best.metrics.matched >= minimumMatchedCount else {
            return nil
        }
        guard matchedGain >= minimumGain || autoGain >= minimumGain || visitGain >= minimumVisitGain else {
            return nil
        }

        if let currentMedian = currentOption.metrics.medianAbsoluteTimeDelta,
           let bestMedian = best.metrics.medianAbsoluteTimeDelta,
           bestMedian > currentMedian * 0.5 {
            return nil
        }

        if let runnerUp = ranked.dropFirst().first,
           runnerUp.offset != currentOption.offset,
           isClearlyBetter(best, than: runnerUp) == false {
            return nil
        }

        return best.offset
    }

    private func isClearlyBetter(_ lhs: CaptureTimeOffsetOption, than rhs: CaptureTimeOffsetOption) -> Bool {
        let matchedGap = lhs.metrics.matched - rhs.metrics.matched
        let visitGap = lhs.metrics.visitContained - rhs.metrics.visitContained
        let autoGap = lhs.metrics.autoSuggested - rhs.metrics.autoSuggested

        if visitGap >= 2 || matchedGap >= 2 || autoGap >= 2 {
            return true
        }

        if let lhsMedian = lhs.metrics.medianAbsoluteTimeDelta,
           let rhsMedian = rhs.metrics.medianAbsoluteTimeDelta,
           rhsMedian - lhsMedian >= 15 * 60 {
            return true
        }

        return false
    }

    private func displayedOptions(
        from ranked: [CaptureTimeOffsetOption],
        currentOption: CaptureTimeOffsetOption,
        recommendedOffset: TimeInterval?
    ) -> [CaptureTimeOffsetOption] {
        var offsets: [TimeInterval] = []

        if let recommendedOffset, recommendedOffset != currentOption.offset {
            offsets.append(recommendedOffset)
        }
        offsets.append(currentOption.offset)

        for option in ranked where offsets.contains(option.offset) == false {
            offsets.append(option.offset)
            if offsets.count >= displayedOptionCount {
                break
            }
        }

        return offsets.compactMap { offset in
            ranked.first { $0.offset == offset }
        }
    }
}
