import Foundation

public struct ReviewSummary: Hashable, Sendable {
    public let totalAssets: Int
    public let autoSuggested: Int
    public let ambiguous: Int
    public let unmatched: Int

    public init(totalAssets: Int, autoSuggested: Int, ambiguous: Int, unmatched: Int) {
        self.totalAssets = totalAssets
        self.autoSuggested = autoSuggested
        self.ambiguous = ambiguous
        self.unmatched = unmatched
    }
}
