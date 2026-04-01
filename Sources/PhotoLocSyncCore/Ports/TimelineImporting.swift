import Foundation

public protocol TimelineImporting: Sendable {
    func loadTimeline(from data: Data) throws -> ImportedTimeline
}
