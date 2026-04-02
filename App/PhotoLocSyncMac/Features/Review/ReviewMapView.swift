import PhotoLocSyncCore
import SwiftUI

struct ReviewMapCluster: Identifiable, Equatable {
    let id: String
    let coordinate: GeoCoordinate
    let count: Int
    let sampleLabel: String
    let sampleAsset: PhotoAsset
    let isSelected: Bool
}

struct ReviewMapPlotPoint: Identifiable, Equatable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let count: Int
    let label: String
    let isSelected: Bool
}

struct ReviewMapPlotHighlight: Identifiable, Equatable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let label: String
}

struct ReviewMapPlotLayout: Equatable {
    let clusterPoints: [ReviewMapPlotPoint]
    let highlightPoints: [ReviewMapPlotHighlight]

    static func make(
        clusters: [ReviewMapCluster],
        selectionTargets: [ReviewMapSelectionTarget],
        in size: CGSize,
        padding: CGFloat = 44
    ) -> Self {
        let coordinates = clusters.map(\.coordinate) + selectionTargets.map(\.coordinate)
        let bounds = ReviewMapCoordinateBounds(coordinates: coordinates)

        let clusterPoints = clusters.map { cluster in
            let projected = bounds.project(cluster.coordinate, in: size, padding: padding)
            return ReviewMapPlotPoint(
                id: cluster.id,
                x: projected.x,
                y: projected.y,
                count: cluster.count,
                label: cluster.sampleLabel,
                isSelected: cluster.isSelected
            )
        }

        let highlightPoints = selectionTargets.map { target in
            let projected = bounds.project(target.coordinate, in: size, padding: padding)
            return ReviewMapPlotHighlight(id: target.id, x: projected.x, y: projected.y, label: target.label)
        }

        return Self(clusterPoints: clusterPoints, highlightPoints: highlightPoints)
    }
}

private struct ReviewMapCoordinateBounds: Equatable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    init(coordinates: [GeoCoordinate]) {
        guard let first = coordinates.first else {
            minLatitude = 0
            maxLatitude = 0
            minLongitude = 0
            maxLongitude = 0
            return
        }

        minLatitude = coordinates.map(\.latitude).min() ?? first.latitude
        maxLatitude = coordinates.map(\.latitude).max() ?? first.latitude
        minLongitude = coordinates.map(\.longitude).min() ?? first.longitude
        maxLongitude = coordinates.map(\.longitude).max() ?? first.longitude
    }

    func project(_ coordinate: GeoCoordinate, in size: CGSize, padding: CGFloat) -> CGPoint {
        let availableWidth = max(size.width - (padding * 2), 1)
        let availableHeight = max(size.height - (padding * 2), 1)
        let center = CGPoint(x: padding + (availableWidth / 2), y: padding + (availableHeight / 2))

        let latitudeSpan = maxLatitude - minLatitude
        let longitudeSpan = maxLongitude - minLongitude
        guard latitudeSpan > .ulpOfOne || longitudeSpan > .ulpOfOne else {
            return center
        }

        let xFraction = longitudeSpan > .ulpOfOne
            ? (coordinate.longitude - minLongitude) / longitudeSpan
            : 0.5
        let yFraction = latitudeSpan > .ulpOfOne
            ? 1 - ((coordinate.latitude - minLatitude) / latitudeSpan)
            : 0.5

        return CGPoint(
            x: padding + (availableWidth * xFraction),
            y: padding + (availableHeight * yFraction)
        )
    }
}

struct ReviewMapView: View {
    let entries: [ReviewSelection]
    let selectedPhotoIDs: Set<String>
    let selectionTargets: [ReviewMapSelectionTarget]

    private var clusters: [ReviewMapCluster] {
        Self.makeClusters(entries: entries, selectedPhotoIDs: selectedPhotoIDs)
    }

    nonisolated static func makeClusters(entries: [ReviewSelection], selectedPhotoIDs: Set<String>) -> [ReviewMapCluster] {
        struct GroupState {
            let coordinate: GeoCoordinate
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
                grouped[key] = GroupState(coordinate: coordinate, entries: [entry])
            }
        }

        return grouped
            .map { key, value in
                let selectedEntries = value.entries.filter { selectedPhotoIDs.contains($0.id) }
                let representative = selectedEntries.first ?? value.entries.first!
                return ReviewMapCluster(
                    id: key,
                    coordinate: value.coordinate,
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
            ContentUnavailableView(
                "No Proposed Coordinates",
                systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                description: Text("Only matched photos appear in the local coordinate plot.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReviewCoordinatePlot(clusters: clusters, selectionTargets: selectionTargets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ReviewCoordinatePlot: View {
    let clusters: [ReviewMapCluster]
    let selectionTargets: [ReviewMapSelectionTarget]

    var body: some View {
        GeometryReader { geometry in
            let layout = ReviewMapPlotLayout.make(
                clusters: clusters,
                selectionTargets: selectionTargets,
                in: geometry.size
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.97, blue: 0.99),
                                Color(red: 0.98, green: 0.98, blue: 0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ReviewCoordinateGrid()
                    .stroke(Color.secondary.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .padding(24)

                ForEach(layout.clusterPoints) { point in
                    ReviewMapPlotBubble(point: point)
                        .position(x: point.x, y: point.y)
                }

                ForEach(layout.highlightPoints) { highlight in
                    ReviewMapPlotHighlightBadge(highlight: highlight)
                        .position(x: highlight.x, y: highlight.y)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("On-device location plot", systemImage: "lock.shield")
                        .font(.headline)
                    Text("Scaled from matched coordinates only. No map tiles, geocoding, or online lookups.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
    }
}

private struct ReviewCoordinateGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps: [CGFloat] = [0.2, 0.4, 0.6, 0.8]

        for step in steps {
            let x = rect.minX + (rect.width * step)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + (rect.height * step)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct ReviewMapPlotBubble: View {
    let point: ReviewMapPlotPoint

    private var fillColor: Color {
        point.isSelected ? Color.accentColor : Color(red: 0.19, green: 0.43, blue: 0.54)
    }

    private var diameter: CGFloat {
        point.count > 1 ? 34 : 22
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)

                Text("\(point.count)")
                    .font(point.count > 1 ? .caption.weight(.bold) : .body.weight(.bold))
                    .foregroundStyle(Color.white)
            }

            Text(point.label)
                .font(.caption2.weight(point.isSelected ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
        .padding(8)
        .background(Color.white.opacity(point.isSelected ? 0.94 : 0.78), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(point.isSelected ? Color.accentColor : Color.secondary.opacity(0.14), lineWidth: point.isSelected ? 2 : 1)
        }
    }
}

private struct ReviewMapPlotHighlightBadge: View {
    let highlight: ReviewMapPlotHighlight

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: 44, height: 44)

            Text(highlight.label)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.94), in: Capsule())
        }
        .offset(y: -10)
    }
}
