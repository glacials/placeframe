import AppKit
import CoreLocation
import MapKit
import PhotoLocSyncAdapters
import PhotoLocSyncCore
import SwiftUI

struct ReviewMapCluster: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let assetIDs: [String]
    let count: Int
    let sampleLabel: String
    let sampleAsset: PhotoAsset
    let isSelected: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.assetIDs == rhs.assetIDs
            && lhs.count == rhs.count
            && lhs.sampleLabel == rhs.sampleLabel
            && lhs.sampleAsset == rhs.sampleAsset
            && lhs.isSelected == rhs.isSelected
    }
}

struct ReviewMapViewportSnapshot: Equatable {
    let centerLatitude: CLLocationDegrees
    let centerLongitude: CLLocationDegrees
    let latitudeDelta: CLLocationDegrees
    let longitudeDelta: CLLocationDegrees

    init(region: MKCoordinateRegion) {
        centerLatitude = region.center.latitude
        centerLongitude = region.center.longitude
        latitudeDelta = region.span.latitudeDelta
        longitudeDelta = region.span.longitudeDelta
    }

    func isMeaningfullyDifferent(from expected: Self) -> Bool {
        let latitudeTolerance = max(expected.latitudeDelta * 0.12, 0.0005)
        let longitudeTolerance = max(expected.longitudeDelta * 0.12, 0.0005)
        let latitudeZoomDelta = Self.relativeDelta(from: expected.latitudeDelta, to: latitudeDelta)
        let longitudeZoomDelta = Self.relativeDelta(from: expected.longitudeDelta, to: longitudeDelta)

        return abs(centerLatitude - expected.centerLatitude) > latitudeTolerance
            || abs(centerLongitude - expected.centerLongitude) > longitudeTolerance
            || latitudeZoomDelta > 0.18
            || longitudeZoomDelta > 0.18
    }

    private static func relativeDelta(from expected: CLLocationDegrees, to current: CLLocationDegrees) -> CLLocationDegrees {
        guard expected != 0 else { return abs(current) }
        return abs(current - expected) / abs(expected)
    }
}

struct ReviewMapView: View {
    let entries: [ReviewSelection]
    let selectedPhotoIDs: Set<String>
    let selectionTargets: [ReviewMapSelectionTarget]
    let thumbnailProvider: PhotoThumbnailProvider
    let selectCluster: ([String]) -> Void

    private var clusters: [ReviewMapCluster] {
        Self.makeClusters(entries: entries, selectedPhotoIDs: selectedPhotoIDs)
    }

    nonisolated static func makeClusters(entries: [ReviewSelection], selectedPhotoIDs: Set<String>) -> [ReviewMapCluster] {
        struct GroupState {
            let coordinate: CLLocationCoordinate2D
            var entries: [ReviewSelection]
        }

        var grouped: [String: GroupState] = [:]

        for entry in entries {
            guard let coordinate = entry.item.proposedCoordinate else { continue }
            let key = Self.roundedCoordinateKey(for: coordinate)

            if var existing = grouped[key] {
                existing.entries.append(entry)
                grouped[key] = existing
            } else {
                grouped[key] = GroupState(
                    coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    entries: [entry]
                )
            }
        }

        return grouped
            .map { key, value in
                let selectedEntries = value.entries.filter { selectedPhotoIDs.contains($0.id) }
                let representative = selectedEntries.first ?? value.entries.first!
                return ReviewMapCluster(
                    id: key,
                    coordinate: value.coordinate,
                    assetIDs: value.entries.map(\.id),
                    count: value.entries.count,
                    sampleLabel: representative.item.locationLabel,
                    sampleAsset: representative.item.asset,
                    isSelected: !selectedEntries.isEmpty
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.id < rhs.id }
                return lhs.count > rhs.count
            }
    }

    private nonisolated static func roundedCoordinateKey(for coordinate: GeoCoordinate) -> String {
        let roundedLatitude = (coordinate.latitude * 1_000).rounded() / 1_000
        let roundedLongitude = (coordinate.longitude * 1_000).rounded() / 1_000
        return "\(roundedLatitude),\(roundedLongitude)"
    }

    var body: some View {
        if clusters.isEmpty {
            ContentUnavailableView("No Proposed Coordinates", systemImage: "map", description: Text("Only matched photos appear on the map."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReviewMapNativeView(
                clusters: clusters,
                selectionTargets: selectionTargets,
                thumbnailProvider: thumbnailProvider,
                selectCluster: selectCluster
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReviewMapNativeView: NSViewRepresentable {
    let clusters: [ReviewMapCluster]
    let selectionTargets: [ReviewMapSelectionTarget]
    let thumbnailProvider: PhotoThumbnailProvider
    let selectCluster: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(thumbnailProvider: thumbnailProvider, selectCluster: selectCluster)
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(ReviewClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.clusterReuseIdentifier)
        context.coordinator.installControls(on: mapView)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.selectCluster = selectCluster
        context.coordinator.update(mapView: nsView, clusters: clusters, selectionTargets: selectionTargets)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let clusterReuseIdentifier = "ReviewClusterAnnotation"

        private let thumbnailProvider: PhotoThumbnailProvider
        var selectCluster: ([String]) -> Void
        private var annotationSignature = ""
        private var cameraSignature = ""
        private var currentClusters: [ReviewMapCluster] = []
        private var currentSelectionTargets: [ReviewMapSelectionTarget] = []
        private var expectedViewport: ReviewMapViewportSnapshot?
        private var pendingViewportChangeCount = 0
        private var viewportUpdateGeneration: UInt = 0
        private weak var mapView: MKMapView?
        private weak var recenterButton: NSButton?

        init(thumbnailProvider: PhotoThumbnailProvider, selectCluster: @escaping ([String]) -> Void) {
            self.thumbnailProvider = thumbnailProvider
            self.selectCluster = selectCluster
        }

        func update(mapView: MKMapView, clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) {
            self.mapView = mapView
            currentClusters = clusters
            currentSelectionTargets = selectionTargets

            let nextAnnotationSignature = Self.makeAnnotationSignature(for: clusters)
            if nextAnnotationSignature != annotationSignature {
                mapView.removeAnnotations(mapView.annotations)
                mapView.addAnnotations(Self.makeAnnotations(clusters: clusters))
                annotationSignature = nextAnnotationSignature
            }

            let nextCameraSignature = Self.makeCameraSignature(for: clusters, selectionTargets: selectionTargets)
            if nextCameraSignature != cameraSignature {
                applyVisibleRegion(to: mapView, clusters: clusters, selectionTargets: selectionTargets)
                cameraSignature = nextCameraSignature
            }
        }

        func installControls(on mapView: MKMapView) {
            guard recenterButton == nil else { return }

            let button = NSButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.image = NSImage(
                systemSymbolName: "location.fill",
                accessibilityDescription: "Recenter map"
            )
            button.imagePosition = .imageOnly
            button.setButtonType(.momentaryPushIn)
            button.controlSize = .large
            button.bezelStyle = .texturedRounded
            button.isBordered = true
            button.toolTip = "Recenter map"
            button.target = self
            button.action = #selector(recenterMap)
            button.isHidden = true
            button.setAccessibilityLabel("Recenter map")

            mapView.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 14),
                button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -14),
                button.widthAnchor.constraint(equalToConstant: 34),
                button.heightAnchor.constraint(equalTo: button.widthAnchor)
            ])

            recenterButton = button
            self.mapView = mapView
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard annotation is ReviewClusterAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Self.clusterReuseIdentifier,
                for: annotation
            ) as? ReviewClusterAnnotationView
            view?.thumbnailProvider = thumbnailProvider
            return view
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let snapshot = ReviewMapViewportSnapshot(region: mapView.region)

            if pendingViewportChangeCount > 0 {
                expectedViewport = snapshot
                pendingViewportChangeCount -= 1
                setRecenterButtonHidden(true)
                return
            }

            guard let expectedViewport else {
                setRecenterButtonHidden(true)
                return
            }

            setRecenterButtonHidden(!snapshot.isMeaningfullyDifferent(from: expectedViewport))
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let clusterAnnotation = view.annotation as? ReviewClusterAnnotation else { return }
            selectCluster(clusterAnnotation.assetIDs)
            mapView.deselectAnnotation(clusterAnnotation, animated: false)
        }

        private static func makeAnnotations(clusters: [ReviewMapCluster]) -> [MKAnnotation] {
            clusters.map(ReviewClusterAnnotation.init(cluster:))
        }

        private static func makeAnnotationSignature(for clusters: [ReviewMapCluster]) -> String {
            clusters
                .map { "\($0.id):\($0.assetIDs.joined(separator: ",")):\($0.count):\($0.sampleLabel):\($0.sampleAsset.id):\($0.isSelected)" }
                .joined(separator: "|")
        }

        private static func makeCameraSignature(for clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) -> String {
            if !selectionTargets.isEmpty {
                return "selection:" + selectionTargets
                    .map { "\($0.id):\($0.coordinate.latitude):\($0.coordinate.longitude)" }
                    .joined(separator: "|")
            }
            return "clusters:" + clusters.map(\.id).joined(separator: "|")
        }

        private static func applyVisibleRegion(to mapView: MKMapView, clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) {
            if let selectedCoordinate = selectionTargets.onlyCoordinate {
                let region = MKCoordinateRegion(
                    center: selectedCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
                mapView.setRegion(mapView.regionThatFits(region), animated: true)
                return
            }

            let coordinates = selectionTargets.isEmpty
                ? clusters.map(\.coordinate)
                : selectionTargets.map {
                    CLLocationCoordinate2D(
                        latitude: $0.coordinate.latitude,
                        longitude: $0.coordinate.longitude
                    )
                }
            guard let firstCoordinate = coordinates.first else { return }

            guard coordinates.uniqueCoordinateCount > 1 else {
                let region = MKCoordinateRegion(
                    center: firstCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(mapView.regionThatFits(region), animated: true)
                return
            }

            let rect = coordinates.reduce(MKMapRect.null) { partialRect, coordinate in
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return partialRect.isNull ? pointRect : partialRect.union(pointRect)
            }

            mapView.setVisibleMapRect(
                rect,
                edgePadding: NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                animated: true
            )
        }

        private func applyVisibleRegion(to mapView: MKMapView, clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) {
            pendingViewportChangeCount += 1
            viewportUpdateGeneration &+= 1
            let generation = viewportUpdateGeneration
            setRecenterButtonHidden(true)
            Self.applyVisibleRegion(to: mapView, clusters: clusters, selectionTargets: selectionTargets)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak mapView] in
                guard
                    let self,
                    let mapView,
                    self.viewportUpdateGeneration == generation
                else {
                    return
                }

                self.expectedViewport = ReviewMapViewportSnapshot(region: mapView.region)
                self.pendingViewportChangeCount = 0
            }
        }

        private func setRecenterButtonHidden(_ hidden: Bool) {
            recenterButton?.isHidden = hidden
        }

        @objc private func recenterMap() {
            guard let mapView else { return }
            applyVisibleRegion(to: mapView, clusters: currentClusters, selectionTargets: currentSelectionTargets)
        }
    }
}

private final class ReviewClusterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let assetIDs: [String]
    let count: Int
    let asset: PhotoAsset
    let isSelected: Bool

    init(cluster: ReviewMapCluster) {
        self.coordinate = cluster.coordinate
        self.title = cluster.sampleLabel
        self.assetIDs = cluster.assetIDs
        self.count = cluster.count
        self.asset = cluster.sampleAsset
        self.isSelected = cluster.isSelected
        super.init()
    }
}

@MainActor
private final class ReviewMapThumbnailCache {
    static let shared = ReviewMapThumbnailCache()

    private var images: [String: CGImage] = [:]

    private init() {}

    func image(for assetID: String) -> CGImage? {
        images[assetID]
    }

    func store(_ image: CGImage, for assetID: String) {
        images[assetID] = image
    }
}

private final class ReviewClusterAnnotationView: MKAnnotationView {
    private static let bubbleSide: CGFloat = 64
    private static let bubbleCornerRadius: CGFloat = 16
    private static let tailSide: CGFloat = 16
    private static let tailOverlap: CGFloat = 6
    private static let horizontalPadding: CGFloat = 6
    private static let topPadding: CGFloat = 4
    private static let viewSize = CGSize(
        width: bubbleSide + (horizontalPadding * 2),
        height: topPadding + bubbleSide + tailSide - tailOverlap
    )

    var thumbnailProvider: PhotoThumbnailProvider? {
        didSet {
            scheduleRefreshContent()
        }
    }

    private let bubbleShadowView = NSView()
    private let bubbleContentView = NSView()
    private let imageLayerView = NSView()
    private let placeholderImageView = NSImageView()
    private let countBadgeView = NSView()
    private let countLabel = NSTextField(labelWithString: "")
    private let tailView = NSView()
    private var loadTask: Task<Void, Never>?
    private var representedAssetID: String?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: Self.viewSize)
        centerOffset = CGPoint(x: 0, y: -(Self.viewSize.height / 2))
        canShowCallout = false
        collisionMode = .rectangle
        displayPriority = .required
        wantsLayer = true
        layer?.masksToBounds = false

        configureSubviews()
        scheduleRefreshContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        representedAssetID = nil
        imageLayerView.layer?.contents = nil
        placeholderImageView.isHidden = false
        countBadgeView.isHidden = true
    }

    override var annotation: (any MKAnnotation)? {
        didSet {
            scheduleRefreshContent()
        }
    }

    private func scheduleRefreshContent() {
        Task { @MainActor [weak self] in
            self?.refreshContent()
        }
    }

    private func configureSubviews() {
        bubbleShadowView.translatesAutoresizingMaskIntoConstraints = false
        bubbleShadowView.wantsLayer = true
        bubbleShadowView.layer?.masksToBounds = false
        addSubview(bubbleShadowView)

        bubbleContentView.translatesAutoresizingMaskIntoConstraints = false
        bubbleContentView.wantsLayer = true
        bubbleContentView.layer?.cornerRadius = Self.bubbleCornerRadius
        bubbleContentView.layer?.masksToBounds = true
        bubbleContentView.layer?.borderWidth = 3
        bubbleContentView.layer?.borderColor = NSColor.white.cgColor
        bubbleContentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bubbleShadowView.addSubview(bubbleContentView)

        imageLayerView.translatesAutoresizingMaskIntoConstraints = false
        imageLayerView.wantsLayer = true
        imageLayerView.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.35).cgColor
        imageLayerView.layer?.contentsGravity = .resizeAspectFill
        imageLayerView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        bubbleContentView.addSubview(imageLayerView)

        placeholderImageView.translatesAutoresizingMaskIntoConstraints = false
        placeholderImageView.image = NSImage(
            systemSymbolName: "photo",
            accessibilityDescription: "Photo preview unavailable"
        )
        placeholderImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        placeholderImageView.contentTintColor = NSColor.white.withAlphaComponent(0.9)
        bubbleContentView.addSubview(placeholderImageView)

        countBadgeView.translatesAutoresizingMaskIntoConstraints = false
        countBadgeView.wantsLayer = true
        countBadgeView.layer?.cornerRadius = 11
        countBadgeView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.74).cgColor
        countBadgeView.layer?.borderWidth = 1
        countBadgeView.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        bubbleContentView.addSubview(countBadgeView)

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.alignment = .center
        countLabel.font = .preferredFont(forTextStyle: .caption1).bold()
        countLabel.textColor = .white
        countLabel.backgroundColor = .clear
        countLabel.isBezeled = false
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countBadgeView.addSubview(countLabel)

        tailView.translatesAutoresizingMaskIntoConstraints = false
        tailView.wantsLayer = true
        tailView.layer?.cornerRadius = 3
        tailView.layer?.backgroundColor = NSColor.white.cgColor
        tailView.layer?.transform = CATransform3DMakeRotation(.pi / 4, 0, 0, 1)
        addSubview(tailView)

        NSLayoutConstraint.activate([
            bubbleShadowView.topAnchor.constraint(equalTo: topAnchor, constant: Self.topPadding),
            bubbleShadowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            bubbleShadowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            bubbleShadowView.heightAnchor.constraint(equalToConstant: Self.bubbleSide),

            bubbleContentView.leadingAnchor.constraint(equalTo: bubbleShadowView.leadingAnchor),
            bubbleContentView.trailingAnchor.constraint(equalTo: bubbleShadowView.trailingAnchor),
            bubbleContentView.topAnchor.constraint(equalTo: bubbleShadowView.topAnchor),
            bubbleContentView.bottomAnchor.constraint(equalTo: bubbleShadowView.bottomAnchor),

            imageLayerView.leadingAnchor.constraint(equalTo: bubbleContentView.leadingAnchor),
            imageLayerView.trailingAnchor.constraint(equalTo: bubbleContentView.trailingAnchor),
            imageLayerView.topAnchor.constraint(equalTo: bubbleContentView.topAnchor),
            imageLayerView.bottomAnchor.constraint(equalTo: bubbleContentView.bottomAnchor),

            placeholderImageView.centerXAnchor.constraint(equalTo: bubbleContentView.centerXAnchor),
            placeholderImageView.centerYAnchor.constraint(equalTo: bubbleContentView.centerYAnchor),

            countBadgeView.leadingAnchor.constraint(equalTo: bubbleContentView.leadingAnchor, constant: 6),
            countBadgeView.bottomAnchor.constraint(equalTo: bubbleContentView.bottomAnchor, constant: -6),
            countBadgeView.heightAnchor.constraint(equalToConstant: 22),
            countBadgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),

            countLabel.leadingAnchor.constraint(equalTo: countBadgeView.leadingAnchor, constant: 7),
            countLabel.trailingAnchor.constraint(equalTo: countBadgeView.trailingAnchor, constant: -7),
            countLabel.topAnchor.constraint(equalTo: countBadgeView.topAnchor, constant: 2),
            countLabel.bottomAnchor.constraint(equalTo: countBadgeView.bottomAnchor, constant: -2),

            tailView.centerXAnchor.constraint(equalTo: bubbleShadowView.centerXAnchor),
            tailView.topAnchor.constraint(equalTo: bubbleShadowView.bottomAnchor, constant: -Self.tailOverlap),
            tailView.widthAnchor.constraint(equalToConstant: Self.tailSide),
            tailView.heightAnchor.constraint(equalTo: tailView.widthAnchor),
            tailView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @MainActor
    private func refreshContent() {
        guard let clusterAnnotation = annotation as? ReviewClusterAnnotation else {
            loadTask?.cancel()
            loadTask = nil
            representedAssetID = nil
            imageLayerView.layer?.contents = nil
            placeholderImageView.isHidden = false
            countBadgeView.isHidden = true
            toolTip = nil
            return
        }

        applySelectionStyle(isSelected: clusterAnnotation.isSelected)
        countBadgeView.isHidden = clusterAnnotation.count <= 1
        countLabel.stringValue = clusterAnnotation.count > 1 ? "\(clusterAnnotation.count)" : ""
        toolTip = clusterAnnotation.count > 1
            ? "\(clusterAnnotation.count) photos near \(clusterAnnotation.title ?? "Unknown location")"
            : clusterAnnotation.title

        let asset = clusterAnnotation.asset
        representedAssetID = asset.id
        loadTask?.cancel()
        loadTask = nil

        if let cachedImage = ReviewMapThumbnailCache.shared.image(for: asset.id) {
            applyImage(cachedImage)
            return
        }

        applyImage(nil)

        guard let thumbnailProvider else { return }

        loadTask = Task { @MainActor [weak self] in
            do {
                if let cachedImage = ReviewMapThumbnailCache.shared.image(for: asset.id) {
                    guard let self, self.representedAssetID == asset.id else { return }
                    self.applyImage(cachedImage)
                    return
                }

                guard let cgImage = try await thumbnailProvider.thumbnail(for: asset, maxPixelSize: 220) else {
                    guard let self, self.representedAssetID == asset.id else { return }
                    self.applyImage(nil)
                    return
                }

                guard !Task.isCancelled else { return }
                ReviewMapThumbnailCache.shared.store(cgImage, for: asset.id)
                guard let self, self.representedAssetID == asset.id else { return }
                self.applyImage(cgImage)
            } catch {
                guard let self, self.representedAssetID == asset.id else { return }
                self.applyImage(nil)
            }
        }
    }

    @MainActor
    private func applyImage(_ image: CGImage?) {
        imageLayerView.layer?.contents = image
        placeholderImageView.isHidden = image != nil
    }

    @MainActor
    private func applySelectionStyle(isSelected: Bool) {
        let shadowColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
            : NSColor.black.withAlphaComponent(0.28).cgColor
        let shadowRadius: CGFloat = isSelected ? 12 : 8
        let shadowOffset = isSelected ? CGSize(width: 0, height: 0) : CGSize(width: 0, height: 4)

        bubbleShadowView.layer?.shadowColor = shadowColor
        bubbleShadowView.layer?.shadowOpacity = 1
        bubbleShadowView.layer?.shadowRadius = shadowRadius
        bubbleShadowView.layer?.shadowOffset = shadowOffset

        tailView.layer?.shadowColor = shadowColor
        tailView.layer?.shadowOpacity = 1
        tailView.layer?.shadowRadius = isSelected ? 6 : 4
        tailView.layer?.shadowOffset = shadowOffset
    }
}

private extension NSFont {
    func bold() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
    }
}

private extension Array where Element == CLLocationCoordinate2D {
    var onlyCoordinate: CLLocationCoordinate2D? {
        uniqueCoordinateCount == 1 ? first : nil
    }

    var uniqueCoordinateCount: Int {
        Set(map { "\($0.latitude),\($0.longitude)" }).count
    }
}

private extension Array where Element == ReviewMapSelectionTarget {
    var onlyCoordinate: CLLocationCoordinate2D? {
        map {
            CLLocationCoordinate2D(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude
            )
        }
        .onlyCoordinate
    }
}
