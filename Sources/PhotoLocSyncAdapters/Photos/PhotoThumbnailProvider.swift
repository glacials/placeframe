@preconcurrency import Photos
import AppKit
import Foundation
import CoreGraphics
import PhotoLocSyncCore

private final class LockedContinuation<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Value, Error>

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: sending Value) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: value)
    }

    func resume(throwing error: sending any Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(throwing: error)
    }
}

public final class PhotoThumbnailProvider: ThumbnailProviding, @unchecked Sendable {
    private let imageManager: PHCachingImageManager
    private let assetResourceManager: PHAssetResourceManager
    private let fileManager: FileManager

    public init(
        imageManager: PHCachingImageManager = PHCachingImageManager(),
        assetResourceManager: PHAssetResourceManager = .default(),
        fileManager: FileManager = .default
    ) {
        self.imageManager = imageManager
        self.assetResourceManager = assetResourceManager
        self.fileManager = fileManager
    }

    public func thumbnail(for asset: PhotoAsset, maxPixelSize: Int) async throws -> CGImage? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil)
        guard let phAsset = results.firstObject else { return nil }
        let targetSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage?, Error>) in
            let lockedContinuation = LockedContinuation(continuation)

            self.imageManager.requestImage(for: phAsset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    lockedContinuation.resume(throwing: error)
                    return
                }
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    lockedContinuation.resume(returning: nil)
                    return
                }
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                    return
                }
                if let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    lockedContinuation.resume(returning: cgImage)
                } else {
                    lockedContinuation.resume(returning: nil)
                }
            }
        }
    }

    public func previewFileURL(for asset: PhotoAsset, in directory: URL) async throws -> URL? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil)
        guard let phAsset = results.firstObject,
              let resource = preferredPreviewResource(for: phAsset) else {
            return nil
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let destinationURL = directory.appendingPathComponent(previewFilename(for: asset, resource: resource))
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL?, Error>) in
            let lockedContinuation = LockedContinuation(continuation)

            self.assetResourceManager.writeData(for: resource, toFile: destinationURL, options: options) { error in
                if let error {
                    try? self.fileManager.removeItem(at: destinationURL)
                    lockedContinuation.resume(throwing: error)
                    return
                }
                lockedContinuation.resume(returning: destinationURL)
            }
        }
    }

    private func preferredPreviewResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = [
            .fullSizePhoto,
            .photo,
            .alternatePhoto
        ]

        for type in preferredTypes {
            if let resource = resources.first(where: { $0.type == type }) {
                return resource
            }
        }

        return resources.first
    }

    private func previewFilename(for asset: PhotoAsset, resource: PHAssetResource) -> String {
        let safeAssetID = asset.id.unicodeScalars.map { scalar in
            switch scalar {
            case "/", ":", "?", "%", "*", "|", "\"", "<", ">":
                "_"
            default:
                Character(scalar)
            }
        }.reduce(into: "") { partialResult, character in
            partialResult.append(character)
        }

        return "\(safeAssetID)-\(resource.originalFilename)"
    }
}
