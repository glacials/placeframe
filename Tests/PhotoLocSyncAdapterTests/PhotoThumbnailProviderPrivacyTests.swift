import Photos
import XCTest
@testable import PhotoLocSyncAdapters

final class PhotoThumbnailProviderPrivacyTests: XCTestCase {
    func testThumbnailRequestsDoNotAllowNetworkAccess() {
        let options = PhotoThumbnailProvider.makeThumbnailRequestOptions()

        XCTAssertFalse(options.isNetworkAccessAllowed)
    }

    func testPreviewRequestsDoNotAllowNetworkAccess() {
        let options = PhotoThumbnailProvider.makePreviewRequestOptions()

        XCTAssertFalse(options.isNetworkAccessAllowed)
    }
}
