import Foundation
import XCTest
@testable import PhotoLocSyncCore

final class CaptureTimeOffsetAnalyzerTests: XCTestCase {
    func testAnalyzeProvidesQuarterHourCustomOffsetsForSelection() {
        let analyzer = CaptureTimeOffsetAnalyzer()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = ImportedTimeline(
            range: base...base.addingTimeInterval(60 * 60),
            points: [
                TimelinePoint(
                    id: "point",
                    timestamp: base,
                    coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
                    source: .timelinePath
                )
            ],
            segments: [],
            recordTypeCounts: ["timelinePath": 1]
        )
        let assets = [
            PhotoAsset(id: "photo", creationDate: base, hasLocation: false)
        ]

        guard let analysis = analyzer.analyze(timeline: timeline, assets: assets) else {
            return XCTFail("Expected analysis")
        }

        XCTAssertNotNil(analysis.option(for: 9.5 * 60 * 60))
        XCTAssertTrue(analysis.options.count <= 3)
        XCTAssertFalse(analysis.options.contains { $0.offset == 9.5 * 60 * 60 })
    }

    func testAnalyzeIncludesCurrentCustomOffsetInDisplayedOptions() {
        let analyzer = CaptureTimeOffsetAnalyzer()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = ImportedTimeline(
            range: base...base.addingTimeInterval(60 * 60),
            points: [
                TimelinePoint(
                    id: "point",
                    timestamp: base,
                    coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
                    source: .timelinePath
                )
            ],
            segments: [],
            recordTypeCounts: ["timelinePath": 1]
        )
        let assets = [
            PhotoAsset(id: "photo", creationDate: base, hasLocation: false)
        ]

        guard let analysis = analyzer.analyze(
            timeline: timeline,
            assets: assets,
            currentOffset: 9.5 * 60 * 60
        ) else {
            return XCTFail("Expected analysis")
        }

        XCTAssertEqual(analysis.currentOption?.offset, 9.5 * 60 * 60)
        XCTAssertTrue(analysis.options.contains { $0.offset == 9.5 * 60 * 60 })
    }
}
