import Foundation

public protocol PhotoLibraryReading: Sendable {
    func fetchCandidateAssets(in range: ClosedRange<Date>) async throws -> [PhotoAsset]
}
