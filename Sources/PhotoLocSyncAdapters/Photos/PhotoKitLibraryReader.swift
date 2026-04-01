import Foundation
@preconcurrency import Photos
import PhotoLocSyncCore

public final class PhotoKitLibraryReader: PhotoLibraryReading, @unchecked Sendable {
    private let authorization: PhotoLibraryAuthorization

    public init(authorization: PhotoLibraryAuthorization = PhotoLibraryAuthorization()) {
        self.authorization = authorization
    }

    public func fetchCandidateAssets(in range: ClosedRange<Date>) async throws -> [PhotoAsset] {
        try await authorization.requestReadWriteAccess()

        return await MainActor.run {
            let importedAssetIDs = self.importedAssetIDs()
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            var importedAssets: [PhotoAsset] = []
            var fallbackAssets: [PhotoAsset] = []

            fetchResult.enumerateObjects { asset, _, _ in
                guard let creationDate = asset.creationDate else { return }
                guard asset.location == nil else { return }
                guard range.contains(creationDate) else { return }
                guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return }

                let photoAsset = PhotoAsset(
                    id: asset.localIdentifier,
                    creationDate: creationDate,
                    hasLocation: asset.location != nil
                )

                if importedAssetIDs.contains(asset.localIdentifier) {
                    importedAssets.append(photoAsset)
                } else if asset.sourceType.contains(.typeUserLibrary) || asset.sourceType.contains(.typeiTunesSynced) {
                    fallbackAssets.append(photoAsset)
                }
            }

            return importedAssets.isEmpty ? fallbackAssets : importedAssets
        }
    }

    private func importedAssetIDs() -> Set<String> {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: nil)
        var assetIDs: Set<String> = []

        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                assetIDs.insert(asset.localIdentifier)
            }
        }

        return assetIDs
    }
}
