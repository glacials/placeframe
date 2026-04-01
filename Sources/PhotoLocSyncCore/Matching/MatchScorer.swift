import Foundation

public struct MatchScorer: Sendable {
    public init() {}

    public func score(delta: TimeInterval, insideStationaryVisit: Bool, policy: MatchPolicy) -> (MatchConfidence, MatchDisposition) {
        let absoluteDelta = abs(delta)

        if insideStationaryVisit && absoluteDelta > policy.maybeThreshold {
            return (.acceptable, .autoSuggested)
        }
        if absoluteDelta <= policy.excellentThreshold {
            return (.excellent, .autoSuggested)
        }
        if absoluteDelta <= policy.acceptableThreshold {
            return (.acceptable, .autoSuggested)
        }
        if absoluteDelta <= policy.maybeThreshold {
            return (.maybe, .ambiguous)
        }
        if insideStationaryVisit {
            return (.maybe, .ambiguous)
        }
        return (.rejected, .unmatched)
    }
}
