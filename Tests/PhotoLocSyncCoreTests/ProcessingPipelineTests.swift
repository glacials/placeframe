import Foundation
import XCTest
@testable import PhotoLocSyncCore

private struct FakeImporter: TimelineImporting {
    let timeline: ImportedTimeline
    func loadTimeline(from data: Data) throws -> ImportedTimeline { timeline }
}

private struct FakeReader: PhotoLibraryReading {
    let assets: [PhotoAsset]
    func fetchCandidateAssets(in range: ClosedRange<Date>) async throws -> [PhotoAsset] { assets }
}

private struct FakeGeocoder: ReverseGeocoding {
    func label(for coordinate: GeoCoordinate) async -> String {
        "Label \(coordinate.latitude),\(coordinate.longitude)"
    }
}

private final class StageRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var stages: [ProcessingStage] = []

    func append(_ stage: ProcessingStage) {
        lock.lock()
        stages.append(stage)
        lock.unlock()
    }
}

final class ProcessingPipelineTests: XCTestCase {
    func testProcessingPipelineBuildsStableReviewItems() async throws {
        let base = Date(timeIntervalSince1970: 1_700_100_000)
        let timeline = ImportedTimeline(
            range: base...(base.addingTimeInterval(20 * 60)),
            points: [
                TimelinePoint(id: "match", timestamp: base.addingTimeInterval(5 * 60), coordinate: GeoCoordinate(latitude: 10, longitude: 20), source: .timelinePath)
            ],
            segments: [],
            recordTypeCounts: ["timelinePath": 1]
        )
        let assets = [
            PhotoAsset(id: "match", creationDate: base.addingTimeInterval(7 * 60), hasLocation: false),
            PhotoAsset(id: "maybe", creationDate: base.addingTimeInterval(58 * 60), hasLocation: false),
        ]
        let pipeline = ProcessingPipeline(
            importer: FakeImporter(timeline: timeline),
            reader: FakeReader(assets: assets),
            geocoder: FakeGeocoder()
        )

        let recorder = StageRecorder()
        let prepared = try await pipeline.prepareReview(from: Data()) { stage in
            recorder.append(stage)
        }
        let seenStages = recorder.stages

        XCTAssertEqual(seenStages, [.readingTimeline, .scanningPhotosLibrary, .matchingLocations, .reverseGeocodingPlaces, .preparingReview])
        XCTAssertEqual(prepared.items.count, 2)
        XCTAssertEqual(prepared.summary.totalAssets, 2)
        XCTAssertEqual(prepared.summary.autoSuggested, 1)
        XCTAssertEqual(prepared.summary.ambiguous, 1)
        XCTAssertEqual(prepared.summary.unmatched, 0)
        XCTAssertNotNil(prepared.items[0].suggestedDecision)
        XCTAssertNotNil(prepared.items[1].suggestedDecision)
        XCTAssertTrue(prepared.items[0].locationLabel.contains("Label"))
    }

    func testProcessingPipelineExcludesUnmatchedPhotosFromReviewItems() async throws {
        let base = Date(timeIntervalSince1970: 1_700_200_000)
        let later = base.addingTimeInterval(90 * 24 * 60 * 60)
        let timeline = ImportedTimeline(
            range: base...later,
            points: [
                TimelinePoint(id: "start", timestamp: base, coordinate: GeoCoordinate(latitude: 40.733521, longitude: -74.172931), source: .visit),
                TimelinePoint(id: "end", timestamp: later, coordinate: GeoCoordinate(latitude: 47.674370, longitude: -122.384957), source: .visit),
            ],
            segments: [],
            recordTypeCounts: ["visit": 2]
        )
        let assets = [
            PhotoAsset(id: "gap-photo", creationDate: base.addingTimeInterval(30 * 24 * 60 * 60), hasLocation: false)
        ]
        let pipeline = ProcessingPipeline(
            importer: FakeImporter(timeline: timeline),
            reader: FakeReader(assets: assets),
            geocoder: FakeGeocoder()
        )

        let prepared = try await pipeline.prepareReview(from: Data()) { _ in }

        XCTAssertTrue(prepared.items.isEmpty)
        XCTAssertEqual(prepared.summary.totalAssets, 0)
        XCTAssertEqual(prepared.summary.autoSuggested, 0)
        XCTAssertEqual(prepared.summary.ambiguous, 0)
        XCTAssertEqual(prepared.summary.unmatched, 1)
    }
}
