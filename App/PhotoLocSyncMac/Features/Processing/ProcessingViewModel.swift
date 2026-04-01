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
            "Resolving proposed coordinates into readable place labels for review."
        case .preparingReview:
            "Preparing thumbnails and review models before any write occurs."
        case .applyingChanges:
            "Writing confirmed GPS locations into Apple Photos."
        }
    }
}
