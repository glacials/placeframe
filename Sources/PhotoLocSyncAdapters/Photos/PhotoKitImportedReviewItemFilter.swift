import Foundation
import ImageIO
@preconcurrency import Photos
import PhotoLocSyncCore

public final class PhotoKitImportedReviewItemFilter: @unchecked Sendable {
    private let metadataClassifier = CameraPhotoMetadataClassifier()

    public init() {}

    public func filterToLikelyCameraItems(_ items: [ReviewItem]) async -> [ReviewItem] {
        guard !items.isEmpty else { return items }

        let importedItemIDs = await MainActor.run {
            self.importedAssetIDs(intersecting: Set(items.map(\.asset.id)))
        }
        guard !importedItemIDs.isEmpty else { return items }

        let allowedImportedIDs = await likelyCameraImportedIDs(in: importedItemIDs)
        return items.filter { item in
            importedItemIDs.contains(item.asset.id) == false || allowedImportedIDs.contains(item.asset.id)
        }
    }

    @MainActor
    private func likelyCameraImportedIDs(in itemIDs: Set<String>) async -> Set<String> {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(itemIDs), options: nil)
        var allowedIDs: Set<String> = []

        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)
            guard let properties = await metadataProperties(for: asset) else {
                allowedIDs.insert(asset.localIdentifier)
                continue
            }

            if metadataClassifier.isLikelyCameraPhoto(properties) {
                allowedIDs.insert(asset.localIdentifier)
            }
        }

        return allowedIDs
    }

    @MainActor
    private func metadataProperties(for asset: PHAsset) async -> [CFString: Any]? {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            asset.requestContentEditingInput(with: options) { input, _ in
                guard let url = input?.fullSizeImageURL else {
                    continuation.resume(returning: nil)
                    return
                }

                let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions),
                      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: properties)
            }
        }
    }

    @MainActor
    private func importedAssetIDs(intersecting itemIDs: Set<String>) -> Set<String> {
        guard !itemIDs.isEmpty else { return [] }

        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: nil)
        var assetIDs: Set<String> = []

        collections.enumerateObjects { collection, _, stop in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                if itemIDs.contains(asset.localIdentifier) {
                    assetIDs.insert(asset.localIdentifier)
                }
            }

            if assetIDs.count == itemIDs.count {
                stop.pointee = true
            }
        }

        return assetIDs
    }
}
