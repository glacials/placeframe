import Foundation

public struct ApplySummary: Hashable, Sendable {
    public let updated: Int
    public let skipped: Int
    public let failed: Int
    public let failures: [WriteResult]

    public init(updated: Int, skipped: Int, failed: Int, failures: [WriteResult]) {
        self.updated = updated
        self.skipped = skipped
        self.failed = failed
        self.failures = failures
    }
}
