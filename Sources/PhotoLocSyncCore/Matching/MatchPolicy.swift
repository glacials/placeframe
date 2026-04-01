import Foundation

public struct MatchPolicy: Sendable {
    public let excellentThreshold: TimeInterval
    public let acceptableThreshold: TimeInterval
    public let maybeThreshold: TimeInterval
    public let candidatePadding: TimeInterval
    public let coverageGapThreshold: TimeInterval

    public init(
        excellentThreshold: TimeInterval = 5 * 60,
        acceptableThreshold: TimeInterval = 15 * 60,
        maybeThreshold: TimeInterval = 60 * 60,
        candidatePadding: TimeInterval = 24 * 60 * 60,
        coverageGapThreshold: TimeInterval = 12 * 60 * 60
    ) {
        self.excellentThreshold = excellentThreshold
        self.acceptableThreshold = acceptableThreshold
        self.maybeThreshold = maybeThreshold
        self.candidatePadding = candidatePadding
        self.coverageGapThreshold = coverageGapThreshold
    }
}
