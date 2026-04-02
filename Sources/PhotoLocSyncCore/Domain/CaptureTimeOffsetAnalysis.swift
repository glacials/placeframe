import Foundation

public struct CaptureTimeOffsetMetrics: Sendable {
    public let totalAssets: Int
    public let autoSuggested: Int
    public let ambiguous: Int
    public let unmatched: Int
    public let visitContained: Int
    public let medianAbsoluteTimeDelta: TimeInterval?

    public init(
        totalAssets: Int,
        autoSuggested: Int,
        ambiguous: Int,
        unmatched: Int,
        visitContained: Int,
        medianAbsoluteTimeDelta: TimeInterval?
    ) {
        self.totalAssets = totalAssets
        self.autoSuggested = autoSuggested
        self.ambiguous = ambiguous
        self.unmatched = unmatched
        self.visitContained = visitContained
        self.medianAbsoluteTimeDelta = medianAbsoluteTimeDelta
    }

    public var matched: Int {
        autoSuggested + ambiguous
    }
}

public struct CaptureTimeOffsetOption: Identifiable, Sendable {
    public let offset: TimeInterval
    public let matches: [MatchCandidate]
    public let metrics: CaptureTimeOffsetMetrics

    public var id: Int {
        Int(offset.rounded())
    }

    public init(offset: TimeInterval, matches: [MatchCandidate], metrics: CaptureTimeOffsetMetrics) {
        self.offset = offset
        self.matches = matches
        self.metrics = metrics
    }
}

public struct CaptureTimeOffsetAnalysis: Sendable {
    public let currentOffset: TimeInterval
    public let recommendedOffset: TimeInterval?
    public let options: [CaptureTimeOffsetOption]

    public init(
        currentOffset: TimeInterval,
        recommendedOffset: TimeInterval?,
        options: [CaptureTimeOffsetOption]
    ) {
        self.currentOffset = currentOffset
        self.recommendedOffset = recommendedOffset
        self.options = options
    }

    public var currentOption: CaptureTimeOffsetOption? {
        option(for: currentOffset)
    }

    public var recommendedOption: CaptureTimeOffsetOption? {
        guard let recommendedOffset else { return nil }
        return option(for: recommendedOffset)
    }

    public func option(for offset: TimeInterval) -> CaptureTimeOffsetOption? {
        options.first { $0.offset == offset }
    }
}
