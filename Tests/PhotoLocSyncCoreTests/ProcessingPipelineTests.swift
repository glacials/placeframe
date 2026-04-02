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
    func resolveLocation(for coordinate: GeoCoordinate) async -> ResolvedLocation {
        ResolvedLocation(
            options: [
                LocationOption(
                    precision: .exact,
                    coordinate: coordinate,
                    label: "Label \(coordinate.latitude),\(coordinate.longitude)"
                )
            ]
        )
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
        XCTAssertEqual(prepared.candidateAssets.map(\.id), assets.map(\.id))
        XCTAssertEqual(prepared.captureTimeOffset, 0)
        XCTAssertNotNil(prepared.items[0].suggestedDecision)
        XCTAssertNotNil(prepared.items[1].suggestedDecision)
        XCTAssertTrue(prepared.items[0].locationLabel.contains("Label"))
        XCTAssertEqual(prepared.items[0].availableLocationOptions.map(\.precision), [.exact])
        XCTAssertEqual(prepared.items[0].suggestedDecision?.precision, .exact)
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

    func testProcessingPipelineSuggestsSystematicCaptureTimeOffsetAndCanApplyIt() async {
        let hour = 60.0 * 60.0
        let base = Date(timeIntervalSince1970: 1_700_400_000)
        let timeline = ImportedTimeline(
            range: base.addingTimeInterval(9 * hour)...base.addingTimeInterval(12 * hour),
            points: [
                TimelinePoint(id: "visit-1", timestamp: base.addingTimeInterval(9 * hour + 15 * 60), coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917), source: .visit),
                TimelinePoint(id: "visit-2", timestamp: base.addingTimeInterval(10 * hour + 15 * 60), coordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107), source: .visit),
                TimelinePoint(id: "visit-3", timestamp: base.addingTimeInterval(11 * hour + 15 * 60), coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023), source: .visit)
            ],
            segments: [
                TimelineSegment(id: "segment-1", kind: .visit, startTime: base.addingTimeInterval(9 * hour), endTime: base.addingTimeInterval(9 * hour + 30 * 60), centerCoordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917)),
                TimelineSegment(id: "segment-2", kind: .visit, startTime: base.addingTimeInterval(10 * hour), endTime: base.addingTimeInterval(10 * hour + 30 * 60), centerCoordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107)),
                TimelineSegment(id: "segment-3", kind: .visit, startTime: base.addingTimeInterval(11 * hour), endTime: base.addingTimeInterval(11 * hour + 30 * 60), centerCoordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023))
            ],
            recordTypeCounts: ["visit": 3]
        )
        let assets = [
            PhotoAsset(id: "photo-1", creationDate: base.addingTimeInterval(5 * 60), hasLocation: false),
            PhotoAsset(id: "photo-2", creationDate: base.addingTimeInterval(15 * 60), hasLocation: false),
            PhotoAsset(id: "photo-3", creationDate: base.addingTimeInterval(hour + 5 * 60), hasLocation: false),
            PhotoAsset(id: "photo-4", creationDate: base.addingTimeInterval(hour + 15 * 60), hasLocation: false),
            PhotoAsset(id: "photo-5", creationDate: base.addingTimeInterval(2 * hour + 5 * 60), hasLocation: false),
            PhotoAsset(id: "photo-6", creationDate: base.addingTimeInterval(2 * hour + 15 * 60), hasLocation: false)
        ]
        let pipeline = ProcessingPipeline(
            importer: FakeImporter(timeline: timeline),
            reader: FakeReader(assets: assets),
            geocoder: FakeGeocoder()
        )

        let baseline = await pipeline.prepareReview(timeline: timeline, assets: assets)
        let adjusted = await pipeline.prepareReview(timeline: timeline, assets: assets, captureTimeOffset: 9 * hour)

        XCTAssertEqual(baseline.captureTimeOffsetAnalysis?.recommendedOffset, 9 * hour)
        XCTAssertTrue(baseline.items.isEmpty)
        XCTAssertEqual(adjusted.captureTimeOffset, 9 * hour)
        XCTAssertEqual(adjusted.summary.totalAssets, 6)
        XCTAssertEqual(adjusted.summary.autoSuggested, 6)
        XCTAssertEqual(adjusted.summary.unmatched, 0)
    }

    func testProcessingPipelineCanApplyDifferentCaptureTimeOffsetsPerDay() async {
        let hour = 60.0 * 60.0
        let base = Date(timeIntervalSince1970: 1_700_500_000)
        let nextDay = base.addingTimeInterval(24 * hour)
        let timeline = ImportedTimeline(
            range: base...nextDay.addingTimeInterval(10 * hour),
            points: [
                TimelinePoint(id: "day-1", timestamp: base.addingTimeInterval(10 * 60), coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917), source: .visit),
                TimelinePoint(id: "day-2", timestamp: nextDay.addingTimeInterval(9 * hour + 10 * 60), coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023), source: .visit)
            ],
            segments: [
                TimelineSegment(id: "segment-1", kind: .visit, startTime: base, endTime: base.addingTimeInterval(30 * 60), centerCoordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917)),
                TimelineSegment(id: "segment-2", kind: .visit, startTime: nextDay.addingTimeInterval(9 * hour), endTime: nextDay.addingTimeInterval(9 * hour + 30 * 60), centerCoordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023))
            ],
            recordTypeCounts: ["visit": 2]
        )
        let dayOneAssets = [
            PhotoAsset(id: "day-1-photo-1", creationDate: base.addingTimeInterval(5 * 60), hasLocation: false),
            PhotoAsset(id: "day-1-photo-2", creationDate: base.addingTimeInterval(15 * 60), hasLocation: false)
        ]
        let dayTwoAssets = [
            PhotoAsset(id: "day-2-photo-1", creationDate: nextDay.addingTimeInterval(5 * 60), hasLocation: false),
            PhotoAsset(id: "day-2-photo-2", creationDate: nextDay.addingTimeInterval(15 * 60), hasLocation: false)
        ]
        let assets = dayOneAssets + dayTwoAssets
        let pipeline = ProcessingPipeline(
            importer: FakeImporter(timeline: timeline),
            reader: FakeReader(assets: assets),
            geocoder: FakeGeocoder()
        )
        let dayTwoStart = Calendar.autoupdatingCurrent.startOfDay(for: nextDay)

        let baseline = await pipeline.prepareReview(timeline: timeline, assets: assets)
        let adjusted = await pipeline.prepareReview(
            timeline: timeline,
            assets: assets,
            captureTimeOffsetsByDayStart: [dayTwoStart: 9 * hour]
        )

        XCTAssertEqual(baseline.summary.totalAssets, 2)
        XCTAssertEqual(baseline.summary.unmatched, 2)
        XCTAssertEqual(adjusted.summary.totalAssets, 4)
        XCTAssertEqual(adjusted.summary.autoSuggested, 4)
        XCTAssertEqual(adjusted.summary.unmatched, 0)
    }
}
