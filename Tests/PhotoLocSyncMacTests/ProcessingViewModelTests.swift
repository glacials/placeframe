import XCTest
@testable import PhotoLocSyncMac
import PhotoLocSyncCore

final class ProcessingViewModelTests: XCTestCase {
    func testImportingPhaseUsesSingleLineImportMessage() {
        let viewModel = ProcessingViewModel.importing

        XCTAssertEqual(viewModel.title, "Importing your Timeline export.")
    }

    func testMatchingStageUsesSingleLineMatchingMessage() {
        let viewModel = ProcessingViewModel(stage: .matchingLocations)

        XCTAssertEqual(viewModel.title, "Matching photos to your timeline.")
    }

    func testPreparingReviewUsesSingleLineReviewMessage() {
        let viewModel = ProcessingViewModel(stage: .preparingReview)

        XCTAssertEqual(viewModel.title, "Building your review.")
    }
}
