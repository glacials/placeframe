import Foundation
import PhotoLocSyncCore

public enum TimelineJSONImporterError: LocalizedError {
    case invalidDate(String)
    case invalidGeo(String)
    case noTimelinePoints

    public var errorDescription: String? {
        switch self {
        case .invalidDate(let value):
            "Could not parse timeline timestamp: \(value)"
        case .invalidGeo(let value):
            "Could not parse timeline coordinate: \(value)"
        case .noTimelinePoints:
            "Timeline file did not contain any usable location points."
        }
    }
}

public struct TimelineJSONImporter: TimelineImporting, Sendable {
    private let schemaProbe: TimelineSchemaProbe

    public init(schemaProbe: TimelineSchemaProbe = TimelineSchemaProbe()) {
        self.schemaProbe = schemaProbe
    }

    public func loadTimeline(from data: Data) throws -> ImportedTimeline {
        let summary = try schemaProbe.probe(data: data)
        let records = try JSONDecoder().decode([RawTimelineRecord].self, from: data)

        var points: [TimelinePoint] = []
        var segments: [TimelineSegment] = []
        points.reserveCapacity(records.count * 2)
        segments.reserveCapacity(records.count)

        for (index, record) in records.enumerated() {
            let startTime = try parseDate(record.startTime)
            let endTime = try parseDate(record.endTime)

            if let visit = record.visit,
               let topCandidate = visit.topCandidate,
               let placeLocation = topCandidate.placeLocation {
                let coordinate = try parseGeoCoordinate(placeLocation)
                let midpoint = startTime.addingTimeInterval(endTime.timeIntervalSince(startTime) / 2)
                points.append(
                    TimelinePoint(
                        id: "visit-\(index)",
                        timestamp: midpoint,
                        coordinate: coordinate,
                        source: .visit,
                        semanticLabel: topCandidate.semanticType
                    )
                )
                segments.append(
                    TimelineSegment(
                        id: "visit-segment-\(index)",
                        kind: .visit,
                        startTime: startTime,
                        endTime: endTime,
                        centerCoordinate: coordinate
                    )
                )
            }

            if let activity = record.activity {
                let startCoordinate = try activity.start.map(parseGeoCoordinate)
                let endCoordinate = try activity.end.map(parseGeoCoordinate)

                if let startCoordinate {
                    points.append(
                        TimelinePoint(
                            id: "activity-start-\(index)",
                            timestamp: startTime,
                            coordinate: startCoordinate,
                            source: .activityStart,
                            semanticLabel: activity.topCandidate?.type
                        )
                    )
                }
                if let endCoordinate {
                    points.append(
                        TimelinePoint(
                            id: "activity-end-\(index)",
                            timestamp: endTime,
                            coordinate: endCoordinate,
                            source: .activityEnd,
                            semanticLabel: activity.topCandidate?.type
                        )
                    )
                }
                segments.append(
                    TimelineSegment(
                        id: "activity-segment-\(index)",
                        kind: .activity,
                        startTime: startTime,
                        endTime: endTime,
                        startCoordinate: startCoordinate,
                        endCoordinate: endCoordinate
                    )
                )
            }

            if let path = record.timelinePath {
                segments.append(
                    TimelineSegment(
                        id: "path-segment-\(index)",
                        kind: .timelinePath,
                        startTime: startTime,
                        endTime: endTime
                    )
                )
                for (pathIndex, pathPoint) in path.enumerated() {
                    let coordinate = try parseGeoCoordinate(pathPoint.point)
                    let timestamp = startTime.addingTimeInterval((Double(pathPoint.durationMinutesOffsetFromStartTime) ?? 0) * 60)
                    points.append(
                        TimelinePoint(
                            id: "path-\(index)-\(pathIndex)",
                            timestamp: timestamp,
                            coordinate: coordinate,
                            source: .timelinePath
                        )
                    )
                }
            }

            if record.timelineMemory != nil {
                segments.append(
                    TimelineSegment(
                        id: "memory-segment-\(index)",
                        kind: .memory,
                        startTime: startTime,
                        endTime: endTime
                    )
                )
            }
        }

        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        guard let lower = sortedPoints.first?.timestamp, let upper = sortedPoints.last?.timestamp else {
            throw TimelineJSONImporterError.noTimelinePoints
        }
        return ImportedTimeline(range: lower...upper, points: sortedPoints, segments: segments, recordTypeCounts: summary.recordTypeCounts)
    }

    private func parseDate(_ value: String) throws -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nonFractional = ISO8601DateFormatter()
        nonFractional.formatOptions = [.withInternetDateTime]
        if let date = fractional.date(from: value) ?? nonFractional.date(from: value) {
            return date
        }
        throw TimelineJSONImporterError.invalidDate(value)
    }

    private func parseGeoCoordinate(_ value: String) throws -> GeoCoordinate {
        guard value.hasPrefix("geo:"), let separator = value.split(separator: ":", maxSplits: 1).last else {
            throw TimelineJSONImporterError.invalidGeo(value)
        }
        let parts = separator.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else {
            throw TimelineJSONImporterError.invalidGeo(value)
        }
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

private struct RawTimelineRecord: Decodable {
    let startTime: String
    let endTime: String
    let visit: RawVisit?
    let activity: RawActivity?
    let timelinePath: [RawTimelinePathPoint]?
    let timelineMemory: RawTimelineMemory?
}

private struct RawVisit: Decodable {
    let hierarchyLevel: String?
    let topCandidate: RawVisitCandidate?
    let probability: String?
}

private struct RawVisitCandidate: Decodable {
    let probability: String?
    let semanticType: String?
    let placeID: String?
    let placeLocation: String?
}

private struct RawActivity: Decodable {
    let start: String?
    let end: String?
    let topCandidate: RawActivityCandidate?
    let distanceMeters: String?
}

private struct RawActivityCandidate: Decodable {
    let type: String?
    let probability: String?
}

private struct RawTimelinePathPoint: Decodable {
    let point: String
    let durationMinutesOffsetFromStartTime: String

    private enum CodingKeys: String, CodingKey {
        case point
        case durationMinutesOffsetFromStartTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point = try container.decode(String.self, forKey: .point)
        if let intValue = try? container.decode(Int.self, forKey: .durationMinutesOffsetFromStartTime) {
            durationMinutesOffsetFromStartTime = String(intValue)
        } else {
            durationMinutesOffsetFromStartTime = try container.decode(String.self, forKey: .durationMinutesOffsetFromStartTime)
        }
    }
}

private struct RawTimelineMemory: Decodable {
    let destinations: [RawTimelineDestination]?
    let distanceFromOriginKms: String?
}

private struct RawTimelineDestination: Decodable {
    let identifier: String?
}
