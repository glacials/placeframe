import PhotoLocSyncCore

struct ProcessingViewModel {
    private let phase: ProcessingProgressPhase

    init(stage: ProcessingStage) {
        self.phase = ProcessingProgressPhase(stage: stage)
    }

    init(phase: ProcessingProgressPhase) {
        self.phase = phase
    }

    static let importing = ProcessingViewModel(phase: .importingFile)

    var title: String { phase.title }
}

enum ProcessingProgressPhase {
    case importingFile
    case readingTimeline
    case scanningPhotosLibrary
    case matchingLocations
    case reverseGeocodingPlaces
    case preparingReview

    init(stage: ProcessingStage) {
        switch stage {
        case .readingTimeline:
            self = .readingTimeline
        case .scanningPhotosLibrary:
            self = .scanningPhotosLibrary
        case .matchingLocations:
            self = .matchingLocations
        case .reverseGeocodingPlaces:
            self = .reverseGeocodingPlaces
        case .preparingReview:
            self = .preparingReview
        }
    }

    var title: String {
        switch self {
        case .importingFile:
            return "Importing your Timeline export."
        case .readingTimeline:
            return "Reading your Timeline history."
        case .scanningPhotosLibrary:
            return "Scanning your Photos library."
        case .matchingLocations:
            return "Matching photos to your timeline."
        case .reverseGeocodingPlaces:
            return "Preparing location labels."
        case .preparingReview:
            return "Building your review."
        }
    }
}
