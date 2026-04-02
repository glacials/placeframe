import XCTest
@testable import PhotoLocSyncMac

@MainActor
final class ImportViewModelTests: XCTestCase {
    func testWizardStartsOnExportStep() {
        let viewModel = ImportViewModel()

        XCTAssertEqual(viewModel.currentStep, .export)
        XCTAssertFalse(viewModel.isFileImporterPresented)
        XCTAssertFalse(viewModel.canGoBack)
    }

    func testPrimaryActionFromExportMovesWizardForwardWithoutOpeningImporter() {
        let viewModel = ImportViewModel()

        viewModel.handlePrimaryAction()

        XCTAssertEqual(viewModel.currentStep, .upload)
        XCTAssertFalse(viewModel.isFileImporterPresented)
        XCTAssertTrue(viewModel.canGoBack)
    }

    func testBackFromUploadReturnsToExportStep() {
        let viewModel = ImportViewModel()
        viewModel.advanceToUpload()

        viewModel.goBack()

        XCTAssertEqual(viewModel.currentStep, .export)
        XCTAssertFalse(viewModel.isFileImporterPresented)
    }

    func testPrimaryActionFromUploadPresentsImporter() {
        let viewModel = ImportViewModel()
        viewModel.advanceToUpload()

        viewModel.handlePrimaryAction()

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
