import Foundation

public struct PhotoAsset: Identifiable, Hashable, Sendable {
    public let id: String
    public let creationDate: Date
    public let hasLocation: Bool

    public init(id: String, creationDate: Date, hasLocation: Bool) {
        self.id = id
        self.creationDate = creationDate
        self.hasLocation = hasLocation
    }
}
