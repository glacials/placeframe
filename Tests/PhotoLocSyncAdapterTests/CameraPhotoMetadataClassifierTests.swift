import ImageIO
import XCTest
@testable import PhotoLocSyncAdapters

final class CameraPhotoMetadataClassifierTests: XCTestCase {
    func testClassifierAcceptsCameraMakeAndModel() {
        let classifier = CameraPhotoMetadataClassifier()
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 16 Pro",
            ]
        ]

        XCTAssertTrue(classifier.isLikelyCameraPhoto(properties))
    }

    func testClassifierAcceptsStrongCaptureSignalsWithoutHardwareIdentifiers() {
        let classifier = CameraPhotoMetadataClassifier()
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifExposureTime: 0.016,
                kCGImagePropertyExifFNumber: 1.8,
                kCGImagePropertyExifISOSpeedRatings: [125],
            ]
        ]

        XCTAssertTrue(classifier.isLikelyCameraPhoto(properties))
    }

    func testClassifierRejectsSoftwareOnlyMetadata() {
        let classifier = CameraPhotoMetadataClassifier()
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFSoftware: "Preview",
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:04:01 10:00:00",
            ],
        ]

        XCTAssertFalse(classifier.isLikelyCameraPhoto(properties))
    }

    func testClassifierRejectsBlankHardwareIdentifiers() {
        let classifier = CameraPhotoMetadataClassifier()
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "   ",
                kCGImagePropertyTIFFModel: "",
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: "\n",
            ],
        ]

        XCTAssertFalse(classifier.isLikelyCameraPhoto(properties))
    }
}
