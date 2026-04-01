import Foundation

public protocol PhotoLibraryWriting: Sendable {
    func apply(_ decisions: [MatchDecision]) async throws -> [WriteResult]
}
