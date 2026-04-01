import CoreGraphics

public protocol ThumbnailProviding: Sendable {
    func thumbnail(for asset: PhotoAsset, maxPixelSize: Int) async throws -> CGImage?
}
