import XCTest
@testable import PhotoLocSyncMac
import PhotoLocSyncCore

final class ProcessingViewModelTests: XCTestCase {
    func testImportingPhaseStartsWithTrustMessagingAndCurrentFirstStep() {
        let viewModel = ProcessingViewModel.importing

        XCTAssertEqual(viewModel.title, "Importing your Timeline export")
        XCTAssertTrue(viewModel.assurance.contains("Nothing is written to Photos"))
        XCTAssertEqual(viewModel.steps.first?.state, .current)
        XCTAssertEqual(viewModel.steps.dropFirst().allSatisfy { $0.state == .upcoming }, true)
        XCTAssertEqual(viewModel.visibleTileCount, 0)
        XCTAssertEqual(viewModel.visiblePinCount, 0)
    }

    func testMatchingStageMarksEarlierWorkCompleteAndMovesTilesTowardMap() {
        let viewModel = ProcessingViewModel(stage: .matchingLocations)

        XCTAssertEqual(
            viewModel.steps.map(\.state),
            [.complete, .complete, .complete, .current, .upcoming, .upcoming]
        )
        XCTAssertEqual(viewModel.title, "Matching photos to your timeline")
        XCTAssertGreaterThan(viewModel.tilePlacementProgress, 0.4)
        XCTAssertGreaterThan(viewModel.visibleTileCount, 60)
        XCTAssertEqual(viewModel.visiblePinCount, 3)
    }

    func testPreparingReviewShowsAllPinsAndFinalStepAsCurrent() {
        let viewModel = ProcessingViewModel(stage: .preparingReview)

        XCTAssertEqual(viewModel.steps.last?.state, .current)
        XCTAssertEqual(viewModel.visibleTileCount, 140)
        XCTAssertEqual(viewModel.visiblePinCount, 6)
        XCTAssertEqual(viewModel.progressValue, 1, accuracy: 0.0001)
    }
}
