import Foundation
import XCTest
@testable import PhotoLocSyncAdapters
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testCopyAndPasteLocationReplacesPendingDecisionAndSelectsTarget() throws {
        let sourceCoordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        let targetCoordinate = GeoCoordinate(latitude: 34.6937, longitude: 135.5023)
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: sourceCoordinate,
            label: "Shinjuku, Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: targetCoordinate,
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, targetItem])

        XCTAssertFalse(viewModel.canPasteLocation(into: targetItem.id))

        viewModel.copyLocation(for: sourceItem.id)

        XCTAssertTrue(viewModel.canPasteLocation(into: targetItem.id))
        XCTAssertFalse(viewModel.canPasteLocation(into: sourceItem.id))

        viewModel.pasteLocation(into: targetItem.id)

        let updatedTarget = try XCTUnwrap(viewModel.selections.first { $0.id == targetItem.id })
        XCTAssertEqual(updatedTarget.item.proposedCoordinate, sourceCoordinate)
        XCTAssertEqual(updatedTarget.item.locationLabel, "Shinjuku, Tokyo")
        XCTAssertEqual(updatedTarget.item.confidence, .excellent)
        XCTAssertEqual(updatedTarget.item.suggestedDecision?.assetID, targetItem.id)
        XCTAssertEqual(updatedTarget.item.suggestedDecision?.coordinate, sourceCoordinate)
        XCTAssertEqual(updatedTarget.copiedFromAssetID, sourceItem.id)
    }

    func testPasteLocationUpdatesFocusedMapPin() {
        let sourceCoordinate = GeoCoordinate(latitude: 51.5007, longitude: -0.1246)
        let targetCoordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: sourceCoordinate,
            label: "London",
            confidence: .acceptable,
            disposition: .autoSuggested
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: targetCoordinate,
            label: "Paris",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, targetItem])

        viewModel.showOnMap(targetItem)
        viewModel.copyLocation(for: sourceItem.id)
        viewModel.pasteLocation(into: targetItem.id)

        XCTAssertEqual(viewModel.selectedPhotoIDs, Set([targetItem.id]))
        XCTAssertEqual(
            viewModel.mapSelectionTargets,
            [ReviewMapSelectionTarget(id: targetItem.id, coordinate: sourceCoordinate, label: "London")]
        )
    }

    func testPasteLocationUpdatesEverySelectedPhoto() throws {
        let sourceCoordinate = GeoCoordinate(latitude: 35.6895, longitude: 139.6917)
        let firstTargetCoordinate = GeoCoordinate(latitude: 34.6937, longitude: 135.5023)
        let secondTargetCoordinate = GeoCoordinate(latitude: 43.0618, longitude: 141.3545)
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: sourceCoordinate,
            label: "Shinjuku, Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let firstTargetItem = makeReviewItem(
            assetID: "first-target-photo",
            coordinate: firstTargetCoordinate,
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let secondTargetItem = makeReviewItem(
            assetID: "second-target-photo",
            coordinate: secondTargetCoordinate,
            label: "Sapporo",
            confidence: .acceptable,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, firstTargetItem, secondTargetItem])

        viewModel.selectPhoto(firstTargetItem.id, mode: .replace)
        viewModel.selectPhoto(secondTargetItem.id, mode: .toggle)
        viewModel.copyLocation(for: sourceItem.id)

        XCTAssertTrue(viewModel.canPasteLocation(into: [firstTargetItem.id, secondTargetItem.id]))

        viewModel.pasteLocation(into: [firstTargetItem.id, secondTargetItem.id])

        let updatedFirstTarget = try XCTUnwrap(viewModel.selections.first { $0.id == firstTargetItem.id })
        let updatedSecondTarget = try XCTUnwrap(viewModel.selections.first { $0.id == secondTargetItem.id })
        XCTAssertEqual(updatedFirstTarget.item.proposedCoordinate, sourceCoordinate)
        XCTAssertEqual(updatedFirstTarget.item.locationLabel, "Shinjuku, Tokyo")
        XCTAssertEqual(updatedFirstTarget.item.confidence, .excellent)
        XCTAssertEqual(updatedFirstTarget.copiedFromAssetID, sourceItem.id)
        XCTAssertEqual(updatedSecondTarget.item.proposedCoordinate, sourceCoordinate)
        XCTAssertEqual(updatedSecondTarget.item.locationLabel, "Shinjuku, Tokyo")
        XCTAssertEqual(updatedSecondTarget.item.confidence, .excellent)
        XCTAssertEqual(updatedSecondTarget.copiedFromAssetID, sourceItem.id)
        XCTAssertEqual(viewModel.selectedPhotoIDs, Set([firstTargetItem.id, secondTargetItem.id]))
        XCTAssertEqual(
            viewModel.mapSelectionTargets,
            [
                ReviewMapSelectionTarget(id: firstTargetItem.id, coordinate: sourceCoordinate, label: "Shinjuku, Tokyo"),
                ReviewMapSelectionTarget(id: secondTargetItem.id, coordinate: sourceCoordinate, label: "Shinjuku, Tokyo")
            ]
        )
    }

    func testSelectingMultiplePhotosProducesMultiPhotoMapSelection() {
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, targetItem])

        viewModel.selectPhoto(sourceItem.id, mode: .replace)
        viewModel.selectPhoto(targetItem.id, mode: .toggle)

        XCTAssertEqual(viewModel.selectedPhotoIDs, Set([sourceItem.id, targetItem.id]))
        XCTAssertEqual(
            viewModel.mapSelectionTargets,
            [
                ReviewMapSelectionTarget(id: sourceItem.id, coordinate: sourceItem.proposedCoordinate!, label: "Tokyo"),
                ReviewMapSelectionTarget(id: targetItem.id, coordinate: targetItem.proposedCoordinate!, label: "Osaka")
            ]
        )
    }

    func testShiftSelectingPhotosSelectsFullRangeBetweenAnchorAndClickedPhoto() {
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let thirdItem = makeReviewItem(
            assetID: "third-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_300_120)
        )
        let fourthItem = makeReviewItem(
            assetID: "fourth-photo",
            coordinate: GeoCoordinate(latitude: 33.5904, longitude: 130.4017),
            label: "Fukuoka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_180)
        )
        let viewModel = makeViewModel(items: [thirdItem, firstItem, fourthItem, secondItem])

        viewModel.selectPhoto(firstItem.id, mode: .replace)
        viewModel.selectPhoto(fourthItem.id, mode: .range(extendExisting: false))

        XCTAssertEqual(
            viewModel.selectedPhotoIDs,
            Set([firstItem.id, secondItem.id, thirdItem.id, fourthItem.id])
        )
        XCTAssertEqual(Set(viewModel.mapSelectionTargets.map(\.id)), Set([firstItem.id, secondItem.id, thirdItem.id, fourthItem.id]))
    }

    func testSelectAllPhotosOnCurrentDayReplacesSelectionWithOnlyCurrentDayEntries() {
        let firstDayFirstItem = makeReviewItem(
            assetID: "first-day-first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let firstDaySecondItem = makeReviewItem(
            assetID: "first-day-second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let secondDayFirstItem = makeReviewItem(
            assetID: "second-day-first-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let secondDaySecondItem = makeReviewItem(
            assetID: "second-day-second-photo",
            coordinate: GeoCoordinate(latitude: 33.5904, longitude: 130.4017),
            label: "Fukuoka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_386_460)
        )
        let viewModel = makeViewModel(items: [secondDaySecondItem, firstDaySecondItem, secondDayFirstItem, firstDayFirstItem])

        viewModel.selectPhoto(firstDayFirstItem.id, mode: .replace)
        viewModel.currentDayIndex = 1

        viewModel.selectAllPhotosOnCurrentDay()

        XCTAssertEqual(viewModel.selectedPhotoIDs, Set([secondDayFirstItem.id, secondDaySecondItem.id]))
        XCTAssertEqual(
            Set(viewModel.mapSelectionTargets.map(\.id)),
            Set([secondDayFirstItem.id, secondDaySecondItem.id])
        )
    }

    func testApplyCurrentDayAppliesEveryPhotoShownAndAdvancesToNextDay() async {
        let recorder = ApplyRecorder()
        let firstDayFirstItem = makeReviewItem(
            assetID: "first-day-first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let firstDaySecondItem = makeReviewItem(
            assetID: "first-day-second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let secondDayItem = makeReviewItem(
            assetID: "second-day-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let viewModel = makeViewModel(items: [secondDayItem, firstDaySecondItem, firstDayFirstItem]) { decision in
            await recorder.record(decision)
        }

        await viewModel.applyCurrentDay()
        let appliedAssetIDs = await recorder.appliedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstDayFirstItem.id, firstDaySecondItem.id])
        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [secondDayItem.id])
        XCTAssertEqual(viewModel.currentDayIndex, 0)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondDayItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 1)
        XCTAssertEqual(viewModel.summary.autoSuggested, 0)
        XCTAssertEqual(viewModel.summary.ambiguous, 1)
        XCTAssertFalse(viewModel.isApplyingCurrentDay)
    }

    func testApplyCurrentDayStopsAtFirstErrorAndKeepsFailedPhotoSelected() async {
        let recorder = ApplyRecorder()
        let firstDayFirstItem = makeReviewItem(
            assetID: "first-day-first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let firstDaySecondItem = makeReviewItem(
            assetID: "first-day-second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let secondDayItem = makeReviewItem(
            assetID: "second-day-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let viewModel = makeViewModel(items: [secondDayItem, firstDaySecondItem, firstDayFirstItem]) { decision in
            if decision.assetID == firstDaySecondItem.id {
                throw UserPresentableError(title: "Apply Failed", message: "No permission.")
            }

            await recorder.record(decision)
        }

        await viewModel.applyCurrentDay()
        let appliedAssetIDs = await recorder.appliedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstDayFirstItem.id])
        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [firstDaySecondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [firstDaySecondItem.id])
        XCTAssertEqual(viewModel.presentedError?.title, "Apply Failed")
        XCTAssertEqual(viewModel.presentedError?.message, "No permission.")
        XCTAssertFalse(viewModel.isApplyingCurrentDay)
    }

    func testApplyChangeRemovesPhotoFromSessionAndAdvancesSelection() async {
        let recorder = ApplyRecorder()
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let viewModel = makeViewModel(items: [firstItem, secondItem]) { decision in
            await recorder.record(decision)
        }

        await viewModel.applyChange(for: firstItem.id)
        let appliedAssetIDs = await recorder.appliedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map { $0.id }, [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 1)
        XCTAssertEqual(viewModel.summary.autoSuggested, 1)
    }

    func testApplyChangeOnLastPhotoOfDayKeepsFocusOnRemainingPhotoThatDay() async {
        let recorder = ApplyRecorder()
        let firstDayFirstItem = makeReviewItem(
            assetID: "first-day-first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let firstDayLastItem = makeReviewItem(
            assetID: "first-day-last-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let secondDayItem = makeReviewItem(
            assetID: "second-day-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let viewModel = makeViewModel(items: [secondDayItem, firstDayLastItem, firstDayFirstItem]) { decision in
            await recorder.record(decision)
        }

        await viewModel.applyChange(for: firstDayLastItem.id)
        let appliedAssetIDs = await recorder.appliedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstDayLastItem.id])
        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [firstDayFirstItem.id])
        XCTAssertEqual(viewModel.currentDayIndex, 0)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [firstDayFirstItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 2)
        XCTAssertEqual(viewModel.summary.autoSuggested, 1)
        XCTAssertEqual(viewModel.summary.ambiguous, 1)
    }

    func testApplyChangesProcessesBatchInReviewOrderAndAdvancesSelection() async {
        let recorder = ApplyRecorder()
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let thirdItem = makeReviewItem(
            assetID: "third-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_300_120)
        )
        let viewModel = makeViewModel(items: [secondItem, thirdItem, firstItem]) { decision in
            await recorder.record(decision)
        }

        await viewModel.applyChanges(for: [secondItem.id, firstItem.id])
        let appliedAssetIDs = await recorder.appliedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstItem.id, secondItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [thirdItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [thirdItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 1)
        XCTAssertEqual(viewModel.summary.autoSuggested, 0)
        XCTAssertEqual(viewModel.summary.ambiguous, 1)
    }

    func testSkipForNowOnLastPhotoOfDayAdvancesToFirstPhotoOfNextDay() {
        let firstDayItem = makeReviewItem(
            assetID: "first-day-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondDayFirstItem = makeReviewItem(
            assetID: "second-day-first-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let secondDaySecondItem = makeReviewItem(
            assetID: "second-day-second-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_460)
        )
        let viewModel = makeViewModel(items: [secondDaySecondItem, firstDayItem, secondDayFirstItem])

        viewModel.skipForNow(firstDayItem.id)

        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [secondDayFirstItem.id, secondDaySecondItem.id])
        XCTAssertEqual(viewModel.currentDayIndex, 0)
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondDayFirstItem.id])
    }

    func testSkipPhotosForNowRemovesMultipleSelectionsAndFocusesNextRemainingPhoto() {
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let thirdItem = makeReviewItem(
            assetID: "third-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_300_120)
        )
        let fourthItem = makeReviewItem(
            assetID: "fourth-photo",
            coordinate: GeoCoordinate(latitude: 33.5904, longitude: 130.4017),
            label: "Fukuoka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_180)
        )
        let viewModel = makeViewModel(items: [thirdItem, firstItem, fourthItem, secondItem])

        viewModel.skipPhotosForNow([thirdItem.id, firstItem.id])

        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [secondItem.id, fourthItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 2)
        XCTAssertEqual(viewModel.summary.autoSuggested, 2)
        XCTAssertEqual(viewModel.summary.ambiguous, 0)
    }

    func testDismissPermanentlyRecordsSuppressedPhotoAndAdvancesSelection() async {
        let recorder = SuppressionRecorder()
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested
        )
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            onDismissPermanently: { assetID in
                await recorder.record(assetID)
            }
        )

        await viewModel.dismissPermanently(firstItem.id)
        let suppressedAssetIDs = await recorder.snapshot()

        XCTAssertEqual(suppressedAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map { $0.id }, [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
    }

    func testDismissPhotosPermanentlySuppressesBatchInReviewOrderAndAdvancesSelection() async {
        let recorder = SuppressionRecorder()
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            creationDate: Date(timeIntervalSince1970: 1_700_300_060)
        )
        let thirdItem = makeReviewItem(
            assetID: "third-photo",
            coordinate: GeoCoordinate(latitude: 43.0642, longitude: 141.3469),
            label: "Sapporo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_300_120)
        )
        let viewModel = makeViewModel(
            items: [secondItem, thirdItem, firstItem],
            onDismissPermanently: { assetID in
                await recorder.record(assetID)
            }
        )

        await viewModel.dismissPhotosPermanently([secondItem.id, firstItem.id])
        let suppressedAssetIDs = await recorder.snapshot()

        XCTAssertEqual(suppressedAssetIDs, [firstItem.id, secondItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [thirdItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [thirdItem.id])
    }

    func testDeletePhotoRemovesSelectionAndUpdatesSummary() async {
        let recorder = DeletionRecorder()
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Shinjuku, Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(
            items: [sourceItem, targetItem],
            onDeletePhoto: { assetID in
                await recorder.record(assetID)
            }
        )

        await viewModel.deletePhoto(sourceItem.id)
        let deletedAssetIDs = await recorder.snapshot()

        XCTAssertEqual(deletedAssetIDs, [sourceItem.id])
        XCTAssertEqual(viewModel.selections.map { $0.id }, [targetItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 1)
        XCTAssertEqual(viewModel.summary.autoSuggested, 0)
        XCTAssertEqual(viewModel.summary.ambiguous, 1)
        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
    }

    func testDeletePhotoClearsCopiedLocationAndPhotoSelectionForDeletedAsset() async {
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: GeoCoordinate(latitude: 51.5007, longitude: -0.1246),
            label: "London",
            confidence: .acceptable,
            disposition: .autoSuggested
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
            label: "Paris",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, targetItem])

        viewModel.copyLocation(for: sourceItem.id)
        viewModel.showOnMap(sourceItem)

        await viewModel.deletePhoto(sourceItem.id)

        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
        XCTAssertTrue(viewModel.mapSelectionTargets.isEmpty)
        XCTAssertFalse(viewModel.canPasteLocation(into: targetItem.id))
    }

    func testDeletePhotoPreservesSelectionAndSurfacesErrorWhenDeleteFails() async {
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Shinjuku, Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let viewModel = makeViewModel(
            items: [sourceItem],
            onDeletePhoto: { _ in
                throw UserPresentableError(title: "Delete Failed", message: "No permission.")
            }
        )

        await viewModel.deletePhoto(sourceItem.id)

        XCTAssertEqual(viewModel.selections.map { $0.id }, [sourceItem.id])
        XCTAssertEqual(viewModel.presentedError?.title, "Delete Failed")
        XCTAssertEqual(viewModel.presentedError?.message, "No permission.")
    }

    private func makeViewModel(
        items: [ReviewItem],
        onApplyDecision: @escaping @Sendable (MatchDecision) async throws -> Void = { _ in },
        onDismissPermanently: @escaping @Sendable (String) async -> Void = { _ in },
        onDeletePhoto: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> ReviewViewModel {
        ReviewViewModel(
            summary: ReviewSummary(
                totalAssets: items.count,
                autoSuggested: items.filter { $0.disposition == .autoSuggested }.count,
                ambiguous: items.filter { $0.disposition == .ambiguous }.count,
                unmatched: 0
            ),
            items: items,
            thumbnailProvider: PhotoThumbnailProvider(),
            onApplyDecision: { decision in
                try await onApplyDecision(decision)
            },
            onDismissPermanently: { assetID in
                await onDismissPermanently(assetID)
            },
            onDeletePhoto: onDeletePhoto,
            onCancel: {}
        )
    }

    private func makeReviewItem(
        assetID: String,
        coordinate: GeoCoordinate,
        label: String,
        confidence: MatchConfidence,
        disposition: MatchDisposition,
        creationDate: Date = Date(timeIntervalSince1970: 1_700_300_000)
    ) -> ReviewItem {
        let asset = PhotoAsset(
            id: assetID,
            creationDate: creationDate,
            hasLocation: false
        )
        let decision = MatchDecision(
            assetID: assetID,
            captureDate: asset.creationDate,
            coordinate: coordinate,
            label: label,
            confidence: confidence
        )

        return ReviewItem(
            asset: asset,
            proposedCoordinate: coordinate,
            locationLabel: label,
            confidence: confidence,
            timeDelta: 60,
            disposition: disposition,
            suggestedDecision: decision
        )
    }
}

private actor DeletionRecorder {
    private var assetIDs: [String] = []

    func record(_ assetID: String) {
        assetIDs.append(assetID)
    }

    func snapshot() -> [String] {
        assetIDs
    }
}

private actor ApplyRecorder {
    private var decisions: [MatchDecision] = []

    func record(_ decision: MatchDecision) {
        decisions.append(decision)
    }

    func appliedAssetIDs() -> [String] {
        decisions.map(\.assetID)
    }
}

private actor SuppressionRecorder {
    private var assetIDs: [String] = []

    func record(_ assetID: String) {
        assetIDs.append(assetID)
    }

    func snapshot() -> [String] {
        assetIDs
    }
}
