import XCTest
@testable import PhotoLocSyncMac

@MainActor
final class ImportViewModelTests: XCTestCase {
    func testWizardStartsOnExportStep() {
        let viewModel = ImportViewModel()

        XCTAssertEqual(viewModel.currentStep, .export)
        XCTAssertFalse(viewModel.isFileImporterPresented)
    }

    func testAdvanceToUploadMovesWizardForwardWithoutOpeningImporter() {
        let viewModel = ImportViewModel()

        viewModel.advanceToUpload()

        XCTAssertEqual(viewModel.currentStep, .upload)
        XCTAssertFalse(viewModel.isFileImporterPresented)
    }

    func testSkipFromExportAdvancesToUploadStep() {
        let viewModel = ImportViewModel()

        viewModel.skipCurrentStep()

        XCTAssertEqual(viewModel.currentStep, .upload)
        XCTAssertFalse(viewModel.isFileImporterPresented)
    }

    func testSkipFromUploadPresentsImporter() {
        let viewModel = ImportViewModel()
        viewModel.advanceToUpload()

        viewModel.skipCurrentStep()

        XCTAssertEqual(viewModel.currentStep, .upload)
        XCTAssertTrue(viewModel.isFileImporterPresented)
    }

    func testResetReturnsWizardToExportStep() {
        let viewModel = ImportViewModel()
        viewModel.presentImporter()
        viewModel.isDropTargeted = true

        viewModel.reset()

        XCTAssertEqual(viewModel.currentStep, .export)
        XCTAssertFalse(viewModel.isFileImporterPresented)
        XCTAssertFalse(viewModel.isDropTargeted)
    }
}
