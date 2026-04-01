import Foundation

public protocol PhotoLibraryWriting: Sendable {
    func apply(_ decisions: [MatchDecision]) async throws -> [WriteResult]
    func deleteAsset(withID assetID: String) async throws
}
