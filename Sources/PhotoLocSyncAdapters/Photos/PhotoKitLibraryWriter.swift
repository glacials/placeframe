import CoreLocation
import Foundation
@preconcurrency import Photos
import PhotoLocSyncCore

public final class PhotoKitLibraryWriter: PhotoLibraryWriting, @unchecked Sendable {
    private let authorization: PhotoLibraryAuthorization

    public init(authorization: PhotoLibraryAuthorization = PhotoLibraryAuthorization()) {
        self.authorization = authorization
    }

    public func apply(_ decisions: [MatchDecision]) async throws -> [WriteResult] {
        try await authorization.requestReadWriteAccess()
        var results: [WriteResult] = []
        results.reserveCapacity(decisions.count)

        for decision in decisions {
            let fetchResult = await MainActor.run {
                PHAsset.fetchAssets(withLocalIdentifiers: [decision.assetID], options: nil)
            }
            guard let asset = await MainActor.run(body: { fetchResult.firstObject }) else {
                results.append(WriteResult(assetID: decision.assetID, outcome: .skipped, message: "Asset no longer exists in Photos."))
                continue
            }

            do {
                try await updateLocation(for: asset, coordinate: decision.coordinate)
                results.append(WriteResult(assetID: decision.assetID, outcome: .updated, message: decision.label))
            } catch {
                results.append(WriteResult(assetID: decision.assetID, outcome: .failed, message: error.localizedDescription))
            }
        }

        return results
    }

    private func updateLocation(for asset: PHAsset, coordinate: GeoCoordinate) async throws {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.location = location
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "PhotoLocSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "PhotoKit did not report a successful write."]))
                }
            }
        }
    }
}
