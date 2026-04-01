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

struct ReviewMapView: View {
    let entries: [ReviewSelection]
    let focus: ReviewMapFocus?

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
            VStack(alignment: .leading, spacing: 12) {
                Text("Showing \(clusters.count) map \(clusters.count == 1 ? "cluster" : "clusters") for \(entries.filter { $0.item.proposedCoordinate != nil }.count) matched photos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ReviewMapNativeView(clusters: clusters, focus: focus)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReviewMapNativeView: NSViewRepresentable {
    let clusters: [ReviewMapCluster]
    let focus: ReviewMapFocus?

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
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Coordinator.focusReuseIdentifier)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.update(mapView: nsView, clusters: clusters, focus: focus)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let clusterReuseIdentifier = "ReviewClusterAnnotation"
        static let focusReuseIdentifier = "ReviewFocusAnnotation"

        private var annotationSignature = ""
        private var cameraSignature = ""

        func update(mapView: MKMapView, clusters: [ReviewMapCluster], focus: ReviewMapFocus?) {
            let nextAnnotationSignature = Self.annotationSignature(for: clusters, focus: focus)
            if nextAnnotationSignature != annotationSignature {
                mapView.removeAnnotations(mapView.annotations)
                mapView.addAnnotations(Self.makeAnnotations(clusters: clusters, focus: focus))
                annotationSignature = nextAnnotationSignature
            }

            let nextCameraSignature = Self.cameraSignature(for: clusters, focus: focus)
            if nextCameraSignature != cameraSignature {
                Self.applyVisibleRegion(to: mapView, clusters: clusters, focus: focus)
                cameraSignature = nextCameraSignature
            }
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

            if annotation is ReviewFocusAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.focusReuseIdentifier,
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

        private static func makeAnnotations(clusters: [ReviewMapCluster], focus: ReviewMapFocus?) -> [MKAnnotation] {
            var annotations: [MKAnnotation] = clusters.map { ReviewClusterAnnotation(cluster: $0) }
            if let focus {
                annotations.append(ReviewFocusAnnotation(focus: focus))
            }
            return annotations
        }

        private static func annotationSignature(for clusters: [ReviewMapCluster], focus: ReviewMapFocus?) -> String {
            let clusterSignature = clusters
                .map { "\($0.id):\($0.count):\($0.sampleLabel)" }
                .joined(separator: "|")
            let focusSignature = focus.map {
                "\($0.id):\($0.coordinate.latitude):\($0.coordinate.longitude):\($0.label)"
            } ?? "none"
            return clusterSignature + "||" + focusSignature
        }

        private static func cameraSignature(for clusters: [ReviewMapCluster], focus: ReviewMapFocus?) -> String {
            if let focus {
                return "focus:\(focus.id):\(focus.coordinate.latitude):\(focus.coordinate.longitude)"
            }
            return "clusters:" + clusters.map(\.id).joined(separator: "|")
        }

        private static func applyVisibleRegion(to mapView: MKMapView, clusters: [ReviewMapCluster], focus: ReviewMapFocus?) {
            if let focus {
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: focus.coordinate.latitude,
                        longitude: focus.coordinate.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
                mapView.setRegion(mapView.regionThatFits(region), animated: true)
                return
            }

            let coordinates = clusters.map(\.coordinate)
            guard let firstCoordinate = coordinates.first else { return }

            guard coordinates.count > 1 else {
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

private final class ReviewFocusAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(focus: ReviewMapFocus) {
        self.coordinate = CLLocationCoordinate2D(
            latitude: focus.coordinate.latitude,
            longitude: focus.coordinate.longitude
        )
        self.title = focus.label
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
