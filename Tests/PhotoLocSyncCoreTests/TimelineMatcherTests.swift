import Foundation
import XCTest
@testable import PhotoLocSyncCore

final class TimelineMatcherTests: XCTestCase {
    func testMatcherProducesDeterministicConfidenceBuckets() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = ImportedTimeline(
            range: base...(base.addingTimeInterval(4 * 60 * 60)),
            points: [
                TimelinePoint(id: "p1", timestamp: base, coordinate: GeoCoordinate(latitude: 35.0, longitude: 139.0), source: .timelinePath),
                TimelinePoint(id: "p2", timestamp: base.addingTimeInterval(10 * 60), coordinate: GeoCoordinate(latitude: 35.1, longitude: 139.1), source: .timelinePath),
            ],
            segments: [
                TimelineSegment(id: "visit", kind: .visit, startTime: base.addingTimeInterval(2 * 60 * 60), endTime: base.addingTimeInterval(4 * 60 * 60), centerCoordinate: GeoCoordinate(latitude: 35.5, longitude: 139.5))
            ],
            recordTypeCounts: ["visit": 1, "timelinePath": 2]
        )

        let assets = [
            PhotoAsset(id: "excellent", creationDate: base.addingTimeInterval(3 * 60), hasLocation: false),
            PhotoAsset(id: "ambiguous", creationDate: base.addingTimeInterval(50 * 60), hasLocation: false),
            PhotoAsset(id: "visit-based", creationDate: base.addingTimeInterval(3 * 60 * 60), hasLocation: false),
        ]

        let matcher = TimelineMatcher()
        let firstPass = matcher.match(assets: assets, timeline: timeline)
        let secondPass = matcher.match(assets: assets, timeline: timeline)

        XCTAssertEqual(firstPass, secondPass)
        XCTAssertEqual(firstPass[0].confidence, .excellent)
        XCTAssertEqual(firstPass[0].disposition, .autoSuggested)
        XCTAssertEqual(firstPass[1].confidence, .maybe)
        XCTAssertEqual(firstPass[1].disposition, .ambiguous)
        XCTAssertEqual(firstPass[2].disposition, .autoSuggested)
        XCTAssertEqual(firstPass[2].point?.coordinate, GeoCoordinate(latitude: 35.5, longitude: 139.5))
    }

    func testMatcherRejectsPhotosInsideLargeTimelineGap() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let later = base.addingTimeInterval(90 * 24 * 60 * 60)
        let timeline = ImportedTimeline(
            range: base...later,
            points: [
                TimelinePoint(id: "p1", timestamp: base, coordinate: GeoCoordinate(latitude: 40.733521, longitude: -74.172931), source: .visit),
                TimelinePoint(id: "p2", timestamp: later, coordinate: GeoCoordinate(latitude: 47.674370, longitude: -122.384957), source: .visit),
            ],
            segments: [],
            recordTypeCounts: ["visit": 2]
        )

        let asset = PhotoAsset(
            id: "gap-photo",
            creationDate: base.addingTimeInterval(30 * 24 * 60 * 60),
            hasLocation: false
        )

        let match = TimelineMatcher().match(assets: [asset], timeline: timeline).first
        XCTAssertEqual(match?.disposition, .unmatched)
        XCTAssertNil(match?.point)
    }
}
