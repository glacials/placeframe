import Foundation
import XCTest
@testable import PhotoLocSyncAdapters
@testable import PhotoLocSyncCore

final class TimelineJSONImporterTests: XCTestCase {
    func testImporterParsesAnonymizedTimelineFixture() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("location-history-anonymized.json")
        let data = try Data(contentsOf: fixtureURL)

        let importer = TimelineJSONImporter()
        let timeline = try importer.loadTimeline(from: data)

        XCTAssertEqual(timeline.recordTypeCounts["visit"], 10)
        XCTAssertEqual(timeline.recordTypeCounts["activity"], 11)
        XCTAssertEqual(timeline.recordTypeCounts["timelinePath"], 58)
        XCTAssertEqual(timeline.recordTypeCounts["timelineMemory"], 1)
        XCTAssertFalse(timeline.points.isEmpty)
        XCTAssertLessThan(timeline.range.lowerBound, timeline.range.upperBound)
        XCTAssertEqual(timeline.segments.count, 80)
        XCTAssertEqual(timeline.points, timeline.points.sorted { $0.timestamp < $1.timestamp })
    }

    func testSchemaProbeRejectsNonArrayPayloads() throws {
        let probe = TimelineSchemaProbe()
        let payload = Data("{\"oops\":true}".utf8)
        XCTAssertThrowsError(try probe.probe(data: payload))
    }

    func testSecurityScopedReaderReadsOrdinaryFiles() throws {
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let expected = Data("{\"hello\":\"world\"}".utf8)
        try expected.write(to: temporaryURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let reader = SecurityScopedFileReader()
        let actual = try reader.readData(from: temporaryURL)

        XCTAssertEqual(actual, expected)
    }
}
