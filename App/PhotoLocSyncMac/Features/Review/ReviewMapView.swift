import AppKit
import CoreLocation
import MapKit
import SwiftUI

private struct ReviewMapCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let sampleLabel: String
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
    let selectionTargets: [ReviewMapSelectionTarget]

    private var clusters: [ReviewMapCluster] {
        var grouped: [String: (coordinate: CLLocationCoordinate2D, count: Int, label: String)] = [:]

        for entry in entries {
            guard let coordinate = entry.item.proposedCoordinate else { continue }
            let roundedLatitude = (coordinate.latitude * 1_000).rounded() / 1_000
            let roundedLongitude = (coordinate.longitude * 1_000).rounded() / 1_000
            let key = "\(roundedLatitude),\(roundedLongitude)"

            if var existing = grouped[key] {
                existing.count += 1
                grouped[key] = existing
            } else {
                grouped[key] = (
                    coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    count: 1,
                    label: entry.item.locationLabel
                )
            }
        }

        return grouped
            .map { key, value in
                ReviewMapCluster(
                    id: key,
                    coordinate: value.coordinate,
                    count: value.count,
                    sampleLabel: value.label
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.id < rhs.id }
                return lhs.count > rhs.count
            }
    }

    var body: some View {
        if clusters.isEmpty {
            ContentUnavailableView("No Proposed Coordinates", systemImage: "map", description: Text("Only matched photos appear on the map."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReviewMapNativeView(clusters: clusters, selectionTargets: selectionTargets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReviewMapNativeView: NSViewRepresentable {
    let clusters: [ReviewMapCluster]
    let selectionTargets: [ReviewMapSelectionTarget]

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.selectionReuseIdentifier)
        context.coordinator.installControls(on: mapView)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.update(mapView: nsView, clusters: clusters, selectionTargets: selectionTargets)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let clusterReuseIdentifier = "ReviewClusterAnnotation"
        static let selectionReuseIdentifier = "ReviewSelectionAnnotation"

        private var annotationSignature = ""
        private var cameraSignature = ""
        private var currentClusters: [ReviewMapCluster] = []
        private var currentSelectionTargets: [ReviewMapSelectionTarget] = []
        private var expectedViewport: ReviewMapViewportSnapshot?
        private var pendingViewportChangeCount = 0
        private var viewportUpdateGeneration: UInt = 0
        private weak var mapView: MKMapView?
        private weak var recenterButton: NSButton?

        func update(mapView: MKMapView, clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) {
            self.mapView = mapView
            currentClusters = clusters
            currentSelectionTargets = selectionTargets

            let nextAnnotationSignature = Self.makeAnnotationSignature(for: clusters, selectionTargets: selectionTargets)
            if nextAnnotationSignature != annotationSignature {
                mapView.removeAnnotations(mapView.annotations)
                mapView.addAnnotations(Self.makeAnnotations(clusters: clusters, selectionTargets: selectionTargets))
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
            if let clusterAnnotation = annotation as? ReviewClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.clusterReuseIdentifier,
                    for: clusterAnnotation
                ) as? ReviewClusterAnnotationView
                view?.annotation = clusterAnnotation
                return view
            }

            if annotation is ReviewSelectionAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.selectionReuseIdentifier,
                    for: annotation
                ) as? MKMarkerAnnotationView
                view?.annotation = annotation
                view?.markerTintColor = .systemRed
                view?.glyphImage = NSImage(
                    systemSymbolName: "mappin.and.ellipse",
                    accessibilityDescription: annotation.title ?? nil
                )
                view?.canShowCallout = false
                view?.displayPriority = .required
                return view
            }

            return nil
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

        private static func makeAnnotations(clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) -> [MKAnnotation] {
            var annotations: [MKAnnotation] = clusters.map { ReviewClusterAnnotation(cluster: $0) }
            annotations.append(contentsOf: selectionTargets.map(ReviewSelectionAnnotation.init(target:)))
            return annotations
        }

        private static func makeAnnotationSignature(for clusters: [ReviewMapCluster], selectionTargets: [ReviewMapSelectionTarget]) -> String {
            let clusterSignature = clusters
                .map { "\($0.id):\($0.count):\($0.sampleLabel)" }
                .joined(separator: "|")
            let selectionSignature = selectionTargets
                .map { "\($0.id):\($0.coordinate.latitude):\($0.coordinate.longitude):\($0.label)" }
                .joined(separator: "|")
            return clusterSignature + "||" + selectionSignature
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
    let count: Int

    init(cluster: ReviewMapCluster) {
        self.coordinate = cluster.coordinate
        self.title = cluster.sampleLabel
        self.count = cluster.count
        super.init()
    }
}

private final class ReviewSelectionAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(target: ReviewMapSelectionTarget) {
        self.coordinate = CLLocationCoordinate2D(
            latitude: target.coordinate.latitude,
            longitude: target.coordinate.longitude
        )
        self.title = target.label
        super.init()
    }
}

private final class ReviewClusterAnnotationView: MKAnnotationView {
    private let countLabel = NSTextField(labelWithString: "")

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        wantsLayer = true
        canShowCallout = false
        layer?.masksToBounds = false

        countLabel.alignment = .center
        countLabel.font = .preferredFont(forTextStyle: .caption2).bold()
        countLabel.textColor = .white
        countLabel.backgroundColor = .clear
        countLabel.isBezeled = false
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            countLabel.topAnchor.constraint(equalTo: topAnchor),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: (any MKAnnotation)? {
        didSet {
            guard let clusterAnnotation = annotation as? ReviewClusterAnnotation else { return }

            let diameter: CGFloat = clusterAnnotation.count > 1 ? 26 : 14
            frame.size = CGSize(width: diameter, height: diameter)
            layer?.cornerRadius = diameter / 2
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 2
            layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
            layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
            layer?.shadowOpacity = 1
            layer?.shadowRadius = 2
            layer?.shadowOffset = CGSize(width: 0, height: 1)

            countLabel.isHidden = clusterAnnotation.count == 1
            countLabel.stringValue = clusterAnnotation.count > 1 ? "\(clusterAnnotation.count)" : ""
            toolTip = clusterAnnotation.count > 1
                ? "\(clusterAnnotation.count) photos near \(clusterAnnotation.title ?? "Unknown location")"
                : clusterAnnotation.title
        }
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
