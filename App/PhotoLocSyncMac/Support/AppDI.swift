import PhotoLocSyncAdapters
import PhotoLocSyncCore

struct AppDI {
    @MainActor
    static func makeAppState() -> AppState {
        let importer = TimelineJSONImporter()
        let reader = PhotoKitLibraryReader()
        let reviewItemFilter = PhotoKitImportedReviewItemFilter()
        let reviewSuppressionStore = ReviewSuppressionStore()
        let locationLabelingSettings = LocationLabelingSettings()
        let geocoder = PreferenceAwareReverseGeocoder(settings: locationLabelingSettings)
        let writer = PhotoKitLibraryWriter()
        let pipeline = ProcessingPipeline(importer: importer, reader: reader, geocoder: geocoder)
        let coordinator = SyncCoordinator(pipeline: pipeline, writer: writer)
        let fileReader = SecurityScopedFileReader()
        let thumbnailProvider = PhotoThumbnailProvider()
        return AppState(
            coordinator: coordinator,
            fileReader: fileReader,
            thumbnailProvider: thumbnailProvider,
            reviewItemFilter: reviewItemFilter,
            reviewSuppressionStore: reviewSuppressionStore,
            locationLabelingSettings: locationLabelingSettings
        )
    }
}
