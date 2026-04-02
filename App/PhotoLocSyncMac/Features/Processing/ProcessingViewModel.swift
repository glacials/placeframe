import PhotoLocSyncCore

struct ProcessingViewModel {
    let phase: ProcessingProgressPhase

    init(stage: ProcessingStage) {
        self.phase = ProcessingProgressPhase(stage: stage)
    }

    init(phase: ProcessingProgressPhase) {
        self.phase = phase
    }

    static let importing = ProcessingViewModel(phase: .importingFile)

    var title: String { phase.title }
    var subtitle: String { phase.subtitle }
    var eyebrow: String { phase.eyebrow }
    var symbolName: String { phase.symbolName }
    var assurance: String {
        "This is the real processing pipeline. Nothing is written to Photos or sent off-device on this screen, and review opens as soon as this finishes."
    }
    var detailPills: [String] { phase.detailPills }
    var mapHeadline: String { phase.mapHeadline }
    var contactSheetHeadline: String { phase.contactSheetHeadline }
    var progressValue: Double { phase.progressValue }
    var stageKey: String { phase.rawValue }
    var visibleTileCount: Int { phase.visibleTileCount }
    var visiblePinCount: Int { phase.visiblePinCount }
    var mapRevealProgress: Double { phase.mapRevealProgress }
    var tilePlacementProgress: Double { phase.tilePlacementProgress }
    var routeProgress: Double { phase.routeProgress }

    var steps: [ProcessingProgressStep] {
        ProcessingProgressPhase.allCases.map { candidate in
            ProcessingProgressStep(
                phase: candidate,
                state: candidate.state(relativeTo: phase)
            )
        }
    }
}

enum ProcessingProgressPhase: String, CaseIterable {
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
            "Importing your Timeline export"
        case .readingTimeline:
            "Reading your Timeline history"
        case .scanningPhotosLibrary:
            "Scanning your Photos library"
        case .matchingLocations:
            "Placing photos onto your route"
        case .reverseGeocodingPlaces:
            "Preparing local location labels"
        case .preparingReview:
            "Building your review board"
        }
    }

    var subtitle: String {
        switch self {
        case .importingFile:
            "Bringing the selected location-history.json file into the app and preparing the matching pipeline."
        case .readingTimeline:
            "Validating the export and extracting the time span we need before touching the Photos library."
        case .scanningPhotosLibrary:
            "Using read-only Photos access to find image assets that still need location metadata."
        case .matchingLocations:
            "Comparing capture times against Timeline visits and motion points so each candidate can land on the map."
        case .reverseGeocodingPlaces:
            "Formatting readable on-device coordinate labels without contacting any external service."
        case .preparingReview:
            "Assembling thumbnails, local plot context, and review cards before you approve anything."
        }
    }

    var eyebrow: String {
        switch self {
        case .importingFile:
            "Import started"
        case .readingTimeline:
            "Timeline decoded"
        case .scanningPhotosLibrary:
            "Photo candidates loading"
        case .matchingLocations:
            "Map placement underway"
        case .reverseGeocodingPlaces:
            "Local labels resolving"
        case .preparingReview:
            "Review workspace almost ready"
        }
    }

    var symbolName: String {
        switch self {
        case .importingFile:
            "square.and.arrow.down.fill"
        case .readingTimeline:
            "doc.text.magnifyingglass"
        case .scanningPhotosLibrary:
            "photo.stack.fill"
        case .matchingLocations:
            "scope"
        case .reverseGeocodingPlaces:
            "mappin.and.ellipse"
        case .preparingReview:
            "rectangle.stack.badge.person.crop.fill"
        }
    }

    var detailPills: [String] {
        switch self {
        case .importingFile:
            [
                "Importing locally",
                "No upload step",
                "Review comes next"
            ]
        case .readingTimeline:
            [
                "Parsing JSON",
                "Bounding the date range",
                "No Photos writes"
            ]
        case .scanningPhotosLibrary:
            [
                "Read-only Photos access",
                "Looking for missing GPS",
                "Building the contact sheet"
            ]
        case .matchingLocations:
            [
                "Deterministic time matching",
                "Tiling photos into the map",
                "Still read-only"
            ]
        case .reverseGeocodingPlaces:
            [
                "On-device coordinate labels",
                "No external lookups",
                "Review is next"
            ]
        case .preparingReview:
            [
                "Thumbnail handoff",
                "Plot and list ready",
                "Awaiting your approval"
            ]
        }
    }

    var contactSheetHeadline: String {
        switch self {
        case .importingFile:
            "Import queue"
        case .readingTimeline:
            "Timeline range"
        case .scanningPhotosLibrary:
            "Photo contact sheet"
        case .matchingLocations:
            "Candidate photos"
        case .reverseGeocodingPlaces:
            "Matched photos"
        case .preparingReview:
            "Review-ready photos"
        }
    }

    var mapHeadline: String {
        switch self {
        case .importingFile:
            "Map preview"
        case .readingTimeline:
            "Timeline coverage"
        case .scanningPhotosLibrary:
            "Map warming up"
        case .matchingLocations:
            "Live placement"
        case .reverseGeocodingPlaces:
            "Local labels"
        case .preparingReview:
            "Review plot"
        }
    }

    var progressValue: Double {
        Double(order + 1) / Double(Self.allCases.count)
    }

    var visibleTileCount: Int {
        switch self {
        case .importingFile:
            3
        case .readingTimeline:
            4
        case .scanningPhotosLibrary:
            6
        case .matchingLocations, .reverseGeocodingPlaces, .preparingReview:
            8
        }
    }

    var visiblePinCount: Int {
        switch self {
        case .importingFile, .readingTimeline:
            0
        case .scanningPhotosLibrary:
            1
        case .matchingLocations:
            3
        case .reverseGeocodingPlaces:
            5
        case .preparingReview:
            6
        }
    }

    var mapRevealProgress: Double {
        switch self {
        case .importingFile:
            0.14
        case .readingTimeline:
            0.22
        case .scanningPhotosLibrary:
            0.38
        case .matchingLocations:
            0.7
        case .reverseGeocodingPlaces:
            0.92
        case .preparingReview:
            1
        }
    }

    var tilePlacementProgress: Double {
        switch self {
        case .importingFile:
            0
        case .readingTimeline:
            0.05
        case .scanningPhotosLibrary:
            0.16
        case .matchingLocations:
            0.48
        case .reverseGeocodingPlaces:
            0.8
        case .preparingReview:
            1
        }
    }

    var routeProgress: Double {
        switch self {
        case .importingFile:
            0.18
        case .readingTimeline:
            0.34
        case .scanningPhotosLibrary:
            0.5
        case .matchingLocations:
            0.76
        case .reverseGeocodingPlaces:
            0.92
        case .preparingReview:
            1
        }
    }

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    func state(relativeTo current: Self) -> ProcessingProgressStep.State {
        if order < current.order {
            return .complete
        }
        if order == current.order {
            return .current
        }
        return .upcoming
    }
}

struct ProcessingProgressStep: Identifiable, Equatable {
    enum State: Equatable {
        case complete
        case current
        case upcoming
    }

    let phase: ProcessingProgressPhase
    let state: State

    var id: String { phase.rawValue }
    var title: String { phase.title }
    var symbolName: String {
        switch state {
        case .complete:
            "checkmark.circle.fill"
        case .current, .upcoming:
            phase.symbolName
        }
    }
}
