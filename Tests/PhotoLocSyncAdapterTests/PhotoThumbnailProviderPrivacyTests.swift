import Photos
import XCTest
@testable import PhotoLocSyncAdapters

final class PhotoThumbnailProviderPrivacyTests: XCTestCase {
    func testThumbnailRequestsAllowICloudBackedPreviewLoading() {
        let options = PhotoThumbnailProvider.makeThumbnailRequestOptions()

        XCTAssertTrue(options.isNetworkAccessAllowed)
    }

    func testPreviewRequestsAllowICloudBackedPreviewLoading() {
        let options = PhotoThumbnailProvider.makePreviewRequestOptions()

        XCTAssertTrue(options.isNetworkAccessAllowed)
    }
}
