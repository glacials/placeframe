import Foundation
@preconcurrency import Photos

public enum PhotoLibraryAuthorizationError: LocalizedError {
    case denied
    case restricted
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .denied:
            "Photos access was denied. Enable read/write Photos access in System Settings."
        case .restricted:
            "Photos access is restricted on this Mac."
        case .unavailable:
            "Unable to determine Photos authorization state."
        }
    }
}

public final class PhotoLibraryAuthorization: @unchecked Sendable {
    public init() {}

    public func requestReadWriteAccess() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        case .denied:
            throw PhotoLibraryAuthorizationError.denied
        case .restricted:
            throw PhotoLibraryAuthorizationError.restricted
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch newStatus {
            case .authorized, .limited:
                return
            case .denied:
                throw PhotoLibraryAuthorizationError.denied
            case .restricted:
                throw PhotoLibraryAuthorizationError.restricted
            default:
                throw PhotoLibraryAuthorizationError.unavailable
            }
        @unknown default:
            throw PhotoLibraryAuthorizationError.unavailable
        }
    }
}
