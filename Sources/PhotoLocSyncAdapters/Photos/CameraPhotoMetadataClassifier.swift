import Foundation
import ImageIO

struct CameraPhotoMetadataClassifier: Sendable {
    func isLikelyCameraPhoto(_ properties: [CFString: Any]) -> Bool {
        let tiff = dictionary(for: kCGImagePropertyTIFFDictionary, in: properties)
        let exif = dictionary(for: kCGImagePropertyExifDictionary, in: properties)

        if hasHardwareIdentifier(in: tiff) || hasHardwareIdentifier(in: exif) {
            return true
        }

        return captureSignalCount(in: exif) >= 2
    }

    private func dictionary(for key: CFString, in properties: [CFString: Any]) -> [CFString: Any] {
        properties[key] as? [CFString: Any] ?? [:]
    }

    private func hasHardwareIdentifier(in properties: [CFString: Any]) -> Bool {
        let keys: [CFString] = [
            kCGImagePropertyTIFFMake,
            kCGImagePropertyTIFFModel,
            kCGImagePropertyExifLensMake,
            kCGImagePropertyExifLensModel,
            kCGImagePropertyExifBodySerialNumber,
            kCGImagePropertyExifCameraOwnerName,
        ]

        return keys.contains { hasMeaningfulValue(for: $0, in: properties) }
    }

    private func captureSignalCount(in properties: [CFString: Any]) -> Int {
        let keys: [CFString] = [
            kCGImagePropertyExifExposureTime,
            kCGImagePropertyExifFNumber,
            kCGImagePropertyExifISOSpeedRatings,
            kCGImagePropertyExifFocalLength,
            kCGImagePropertyExifShutterSpeedValue,
            kCGImagePropertyExifApertureValue,
            kCGImagePropertyExifExposureProgram,
            kCGImagePropertyExifFlash,
        ]

        return keys.reduce(into: 0) { count, key in
            if hasMeaningfulValue(for: key, in: properties) {
                count += 1
            }
        }
    }

    private func hasMeaningfulValue(for key: CFString, in properties: [CFString: Any]) -> Bool {
        guard let value = properties[key] else { return false }

        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        if let values = value as? [Any] {
            return values.isEmpty == false
        }

        return true
    }
}
