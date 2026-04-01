import PhotoLocSyncAdapters
import PhotoLocSyncCore

struct AppDI {
    @MainActor
    static func makeAppState() -> AppState {
        let importer = TimelineJSONImporter()
        let reader = PhotoKitLibraryReader()
        let reviewItemFilter = PhotoKitImportedReviewItemFilter()
        let geocoder = CLGeocoderAdapter()
        let writer = PhotoKitLibraryWriter()
        let pipeline = ProcessingPipeline(importer: importer, reader: reader, geocoder: geocoder)
        let coordinator = SyncCoordinator(pipeline: pipeline, writer: writer)
        let fileReader = SecurityScopedFileReader()
        let thumbnailProvider = PhotoThumbnailProvider()
        return AppState(
            coordinator: coordinator,
            fileReader: fileReader,
            thumbnailProvider: thumbnailProvider,
            reviewItemFilter: reviewItemFilter
        )
    }
}
