import PhotoLocSyncCore

struct ProcessingViewModel {
    let stage: ProcessingStage

    var title: String { stage.title }
    var subtitle: String {
        switch stage {
        case .readingTimeline:
            "Reading and validating the imported Timeline JSON file."
        case .scanningPhotosLibrary:
            "Requesting Photos access and scanning for image assets that are missing location metadata."
        case .matchingLocations:
            "Calculating the best deterministic timeline matches for each candidate photo."
        case .reverseGeocodingPlaces:
            "Formatting readable on-device coordinate labels without contacting any external service."
        case .preparingReview:
            "Preparing thumbnails and review models before any write occurs."
        }
    }
}
