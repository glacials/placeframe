import Foundation

public enum WriteOutcome: String, Codable, Sendable {
    case updated
    case skipped
    case failed
}

public struct WriteResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let assetID: String
    public let outcome: WriteOutcome
    public let message: String?

    public init(assetID: String, outcome: WriteOutcome, message: String? = nil) {
        self.id = assetID
        self.assetID = assetID
        self.outcome = outcome
        self.message = message
    }
}
