import Foundation

public enum ProcessingStage: String, CaseIterable, Sendable {
    case readingTimeline
    case scanningPhotosLibrary
    case matchingLocations
    case reverseGeocodingPlaces
    case preparingReview

    public var title: String {
        switch self {
        case .readingTimeline: "Reading Timeline file"
        case .scanningPhotosLibrary: "Scanning Photos library"
        case .matchingLocations: "Matching locations"
        case .reverseGeocodingPlaces: "Preparing location labels"
        case .preparingReview: "Preparing review"
        }
    }
}
