import Foundation
import XCTest
@testable import PhotoLocSyncAdapters
@testable import PhotoLocSyncCore
@testable import PhotoLocSyncMac

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testCancelInvokesExitAction() {
        let item = makeReviewItem(
            assetID: "review-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Shinjuku, Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested
        )
        let cancellationFlag = CancellationFlag()
        let viewModel = makeViewModel(
            items: [item],
            onCancel: { cancellationFlag.didCancel = true }
        )

        viewModel.cancel()

        XCTAssertTrue(cancellationFlag.didCancel)
    }

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

    func testPasteLocationCarriesSelectedPrecisionAndOptionsFromSourcePhoto() throws {
        let exactCoordinate = GeoCoordinate(latitude: 35.7101, longitude: 139.8107)
        let cityCoordinate = GeoCoordinate(latitude: 35.6764, longitude: 139.6500)
        let regionCoordinate = GeoCoordinate(latitude: 36.2048, longitude: 138.2529)
        let countryCoordinate = GeoCoordinate(latitude: 36.2048, longitude: 138.2529)
        let sourceItem = makeReviewItem(
            assetID: "source-photo",
            coordinate: exactCoordinate,
            label: "Ueno Zoo, Tokyo, Japan",
            confidence: .excellent,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: exactCoordinate, label: "Ueno Zoo, Tokyo, Japan"),
                LocationOption(precision: .city, coordinate: cityCoordinate, label: "Tokyo, Japan"),
                LocationOption(precision: .region, coordinate: regionCoordinate, label: "Tokyo Prefecture, Japan"),
                LocationOption(precision: .country, coordinate: countryCoordinate, label: "Japan")
            ],
            selectedPrecision: .country
        )
        let targetItem = makeReviewItem(
            assetID: "target-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let viewModel = makeViewModel(items: [sourceItem, targetItem])

        viewModel.copyLocation(for: sourceItem.id)
        viewModel.pasteLocation(into: targetItem.id)

        let updatedTarget = try XCTUnwrap(viewModel.selections.first { $0.id == targetItem.id })
        XCTAssertEqual(updatedTarget.item.locationLabel, "Japan")
        XCTAssertEqual(updatedTarget.item.proposedCoordinate, countryCoordinate)
        XCTAssertEqual(updatedTarget.item.suggestedDecision?.precision, .country)
        XCTAssertEqual(updatedTarget.item.availableLocationOptions.map(\.precision), [.exact, .city, .region, .country])
    }

    func testSelectLocationPrecisionUpdatesPendingDecisionAndFocusedMapPin() throws {
        let exactCoordinate = GeoCoordinate(latitude: 40.7678, longitude: -73.9718)
        let cityCoordinate = GeoCoordinate(latitude: 40.7128, longitude: -74.0060)
        let regionCoordinate = GeoCoordinate(latitude: 43.0000, longitude: -75.0000)
        let countryCoordinate = GeoCoordinate(latitude: 39.8283, longitude: -98.5795)
        let item = makeReviewItem(
            assetID: "photo",
            coordinate: exactCoordinate,
            label: "Central Park Zoo, New York, NY, United States",
            confidence: .excellent,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: exactCoordinate, label: "Central Park Zoo, New York, NY, United States"),
                LocationOption(precision: .city, coordinate: cityCoordinate, label: "New York, NY, United States"),
                LocationOption(precision: .region, coordinate: regionCoordinate, label: "NY, United States"),
                LocationOption(precision: .country, coordinate: countryCoordinate, label: "United States")
            ]
        )
        let viewModel = makeViewModel(items: [item])

        viewModel.showOnMap(item)
        viewModel.selectLocationPrecision(.city, for: item.id)

        let updatedItem = try XCTUnwrap(viewModel.selections.first { $0.id == item.id })
        XCTAssertEqual(updatedItem.item.locationLabel, "New York, NY, United States")
        XCTAssertEqual(updatedItem.item.proposedCoordinate, cityCoordinate)
        XCTAssertEqual(updatedItem.item.suggestedDecision?.precision, .city)
        XCTAssertEqual(
            viewModel.mapSelectionTargets,
            [ReviewMapSelectionTarget(id: item.id, coordinate: cityCoordinate, label: "New York, NY, United States")]
        )
    }

    func testSelectLocationPrecisionUpdatesEverySelectedPhoto() throws {
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107),
            label: "Ueno Zoo, Tokyo, Japan",
            confidence: .excellent,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107), label: "Ueno Zoo, Tokyo, Japan"),
                LocationOption(precision: .city, coordinate: GeoCoordinate(latitude: 35.6764, longitude: 139.6500), label: "Tokyo, Japan"),
                LocationOption(precision: .country, coordinate: GeoCoordinate(latitude: 36.2048, longitude: 138.2529), label: "Japan")
            ]
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6654, longitude: 135.4323),
            label: "Osaka Aquarium Kaiyukan, Osaka, Japan",
            confidence: .acceptable,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: GeoCoordinate(latitude: 34.6654, longitude: 135.4323), label: "Osaka Aquarium Kaiyukan, Osaka, Japan"),
                LocationOption(precision: .city, coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023), label: "Osaka, Japan"),
                LocationOption(precision: .country, coordinate: GeoCoordinate(latitude: 36.2048, longitude: 138.2529), label: "Japan")
            ]
        )
        let viewModel = makeViewModel(items: [firstItem, secondItem])

        viewModel.selectPhoto(firstItem.id, mode: .replace)
        viewModel.selectPhoto(secondItem.id, mode: .toggle)
        viewModel.selectLocationPrecision(.city, for: [firstItem.id, secondItem.id])

        let updatedFirstItem = try XCTUnwrap(viewModel.selections.first { $0.id == firstItem.id })
        let updatedSecondItem = try XCTUnwrap(viewModel.selections.first { $0.id == secondItem.id })
        XCTAssertEqual(updatedFirstItem.item.locationLabel, "Tokyo, Japan")
        XCTAssertEqual(updatedFirstItem.item.suggestedDecision?.precision, .city)
        XCTAssertEqual(updatedSecondItem.item.locationLabel, "Osaka, Japan")
        XCTAssertEqual(updatedSecondItem.item.suggestedDecision?.precision, .city)
        XCTAssertEqual(viewModel.selectedPhotoIDs, Set([firstItem.id, secondItem.id]))
    }

    func testAvailableLocationPrecisionsReturnsIntersectionAcrossSelection() {
        let firstItem = makeReviewItem(
            assetID: "first-photo",
            coordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107),
            label: "Tokyo",
            confidence: .excellent,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: GeoCoordinate(latitude: 35.7101, longitude: 139.8107), label: "Ueno Zoo, Tokyo, Japan"),
                LocationOption(precision: .city, coordinate: GeoCoordinate(latitude: 35.6764, longitude: 139.6500), label: "Tokyo, Japan"),
                LocationOption(precision: .country, coordinate: GeoCoordinate(latitude: 36.2048, longitude: 138.2529), label: "Japan")
            ]
        )
        let secondItem = makeReviewItem(
            assetID: "second-photo",
            coordinate: GeoCoordinate(latitude: 34.6654, longitude: 135.4323),
            label: "Osaka",
            confidence: .acceptable,
            disposition: .autoSuggested,
            options: [
                LocationOption(precision: .exact, coordinate: GeoCoordinate(latitude: 34.6654, longitude: 135.4323), label: "Osaka Aquarium Kaiyukan, Osaka, Japan"),
                LocationOption(precision: .city, coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023), label: "Osaka, Japan"),
                LocationOption(precision: .region, coordinate: GeoCoordinate(latitude: 34.8000, longitude: 135.5000), label: "Osaka Prefecture, Japan"),
                LocationOption(precision: .country, coordinate: GeoCoordinate(latitude: 36.2048, longitude: 138.2529), label: "Japan")
            ]
        )
        let viewModel = makeViewModel(items: [firstItem, secondItem])

        XCTAssertEqual(viewModel.availableLocationPrecisions(for: [firstItem.id, secondItem.id]), [.exact, .city, .country])
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

    func testMoveKeyboardSelectionStartsAtFirstPhotoOnCurrentDay() {
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
        let viewModel = makeViewModel(items: [secondItem, firstItem])

        viewModel.moveKeyboardSelection(.next)

        XCTAssertEqual(viewModel.selectedPhotoIDs, [firstItem.id])
        XCTAssertEqual(viewModel.focusedPhotoID, firstItem.id)
    }

    func testMoveKeyboardSelectionCollapsesMultiSelectionAroundKeyboardFocus() {
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
        let viewModel = makeViewModel(items: [thirdItem, firstItem, secondItem])

        viewModel.selectPhoto(firstItem.id, mode: .replace)
        viewModel.selectPhoto(secondItem.id, mode: .toggle)
        viewModel.moveKeyboardSelection(.next)

        XCTAssertEqual(viewModel.selectedPhotoIDs, [thirdItem.id])
        XCTAssertEqual(viewModel.focusedPhotoID, thirdItem.id)
    }

    func testMoveKeyboardSelectionUpWithoutSelectionStartsAtLastPhotoOnCurrentDay() {
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
        let viewModel = makeViewModel(items: [secondItem, thirdItem, firstItem])

        viewModel.moveKeyboardSelection(.previous)

        XCTAssertEqual(viewModel.selectedPhotoIDs, [thirdItem.id])
        XCTAssertEqual(viewModel.focusedPhotoID, thirdItem.id)
    }

    func testGoToNextDayAndFocusFirstPhotoSelectsFirstEntryForKeyboardFlow() {
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

        viewModel.goToNextDayAndFocusFirstPhoto()

        XCTAssertEqual(viewModel.currentDayIndex, 1)
        XCTAssertEqual(viewModel.currentDaySection?.entries.map(\.id), [secondDayFirstItem.id, secondDaySecondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondDayFirstItem.id])
        XCTAssertEqual(viewModel.focusedPhotoID, secondDayFirstItem.id)
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

    func testApplyFocusedPhotoUsesKeyboardFocusedSelection() async {
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

        viewModel.selectPhoto(firstItem.id, mode: .replace)
        viewModel.selectPhoto(secondItem.id, mode: .toggle)
        await viewModel.applyFocusedPhoto()

        let appliedAssetIDs = await recorder.appliedAssetIDs()
        XCTAssertEqual(appliedAssetIDs, [secondItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [firstItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [firstItem.id])
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

    func testUndoApplyRestoresPhotoAndClearsWrittenLocation() async {
        let applyRecorder = ApplyRecorder()
        let undoRecorder = DecisionBatchRecorder()
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
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            onApplyDecision: { decision in
                await applyRecorder.record(decision)
            },
            onUndoAppliedDecisions: { decisions in
                await undoRecorder.record(decisions)
            }
        )

        await viewModel.applyChange(for: firstItem.id)

        XCTAssertTrue(viewModel.canUndo)
        XCTAssertEqual(viewModel.undoTitle, "Undo Apply")
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])

        await viewModel.undoLastAction()

        let appliedAssetIDs = await applyRecorder.appliedAssetIDs()
        let undoneAssetIDs = await undoRecorder.recordedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstItem.id])
        XCTAssertEqual(undoneAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [firstItem.id, secondItem.id])
        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
        XCTAssertEqual(viewModel.summary.totalAssets, 2)
        XCTAssertTrue(viewModel.canRedo)
        XCTAssertEqual(viewModel.redoTitle, "Redo Apply")
    }

    func testRedoApplyReappliesDecisionAndRestoresPostApplyFocus() async {
        let applyRecorder = ApplyRecorder()
        let undoRecorder = DecisionBatchRecorder()
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
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            onApplyDecision: { decision in
                await applyRecorder.record(decision)
            },
            onUndoAppliedDecisions: { decisions in
                await undoRecorder.record(decisions)
            }
        )

        await viewModel.applyChange(for: firstItem.id)
        await viewModel.undoLastAction()
        await viewModel.redoLastAction()

        let appliedAssetIDs = await applyRecorder.appliedAssetIDs()
        let undoneAssetIDs = await undoRecorder.recordedAssetIDs()

        XCTAssertEqual(appliedAssetIDs, [firstItem.id, firstItem.id])
        XCTAssertEqual(undoneAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
    }

    func testApplyChangeLeavesPhotoBlankForeverWhenThatChoiceIsSelected() async {
        let applyRecorder = ApplyRecorder()
        let suppressionRecorder = SuppressionRecorder()
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
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            onApplyDecision: { decision in
                await applyRecorder.record(decision)
            },
            onDismissPermanently: { item in
                await suppressionRecorder.record(item.id)
            }
        )

        viewModel.selectLeaveBlank(for: firstItem.id)
        await viewModel.applyChange(for: firstItem.id)

        let appliedAssetIDs = await applyRecorder.appliedAssetIDs()
        let suppressedAssetIDs = await suppressionRecorder.snapshot()

        XCTAssertEqual(appliedAssetIDs, [])
        XCTAssertEqual(suppressedAssetIDs, [firstItem.id])
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertEqual(viewModel.undoTitle, "Undo Leave Blank")
        XCTAssertEqual(viewModel.selections.map(\.id), [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
        XCTAssertEqual(viewModel.summary.totalAssets, 1)
        XCTAssertEqual(viewModel.summary.autoSuggested, 1)
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

    func testUndoAndRedoSkipForNowRestoreThenRemovePhoto() async {
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
        let viewModel = makeViewModel(items: [firstItem, secondItem])

        viewModel.skipForNow(firstItem.id)

        XCTAssertEqual(viewModel.undoTitle, "Undo Leave Blank")
        XCTAssertEqual(viewModel.selections.map(\.id), [secondItem.id])

        await viewModel.undoLastAction()

        XCTAssertEqual(viewModel.selections.map(\.id), [firstItem.id, secondItem.id])
        XCTAssertTrue(viewModel.selectedPhotoIDs.isEmpty)
        XCTAssertTrue(viewModel.canRedo)

        await viewModel.redoLastAction()

        XCTAssertEqual(viewModel.selections.map(\.id), [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
        XCTAssertFalse(viewModel.canRedo)
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
            onDismissPermanently: { item in
                await recorder.record(item.id)
            }
        )

        await viewModel.dismissPermanently(firstItem.id)
        let suppressedAssetIDs = await recorder.snapshot()

        XCTAssertEqual(suppressedAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map { $0.id }, [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
    }

    func testUndoAndRedoDismissPermanentlyRestoreAndResuppressPhoto() async {
        let suppressionRecorder = SuppressionRecorder()
        let unsuppressionRecorder = AssetBatchRecorder()
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
        let viewModel = makeViewModel(
            items: [firstItem, secondItem],
            onDismissPermanently: { item in
                await suppressionRecorder.record(item.id)
            },
            onUndoDismissPermanently: { assetIDs in
                await unsuppressionRecorder.record(assetIDs)
            }
        )

        await viewModel.dismissPermanently(firstItem.id)
        await viewModel.undoLastAction()
        await viewModel.redoLastAction()

        let suppressedAssetIDs = await suppressionRecorder.snapshot()
        let unsuppressedAssetIDs = await unsuppressionRecorder.snapshot()

        XCTAssertEqual(suppressedAssetIDs, [firstItem.id, firstItem.id])
        XCTAssertEqual(unsuppressedAssetIDs, [firstItem.id])
        XCTAssertEqual(viewModel.selections.map(\.id), [secondItem.id])
        XCTAssertEqual(viewModel.selectedPhotoIDs, [secondItem.id])
    }

    func testNewActionClearsRedoHistory() async {
        let applyRecorder = ApplyRecorder()
        let undoRecorder = DecisionBatchRecorder()
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
            items: [firstItem, secondItem, thirdItem],
            onApplyDecision: { decision in
                await applyRecorder.record(decision)
            },
            onUndoAppliedDecisions: { decisions in
                await undoRecorder.record(decisions)
            }
        )

        await viewModel.applyChange(for: firstItem.id)
        await viewModel.undoLastAction()

        XCTAssertTrue(viewModel.canRedo)

        viewModel.skipForNow(thirdItem.id)

        XCTAssertFalse(viewModel.canRedo)
        XCTAssertEqual(viewModel.selections.map(\.id), [firstItem.id, secondItem.id])
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
            onDismissPermanently: { item in
                await recorder.record(item.id)
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

    func testPresentCaptureTimeOffsetSheetDefaultsToRecommendedOption() {
        let item = makeReviewItem(
            assetID: "source-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let dayStart = Calendar.autoupdatingCurrent.startOfDay(for: item.asset.creationDate)
        let analysis = makeCaptureTimeOffsetAnalysis(assetIDs: [item.id], recommendedOffset: 9 * 60 * 60)
        let viewModel = makeViewModel(
            items: [item],
            captureTimeOffsetAnalysesByDay: [dayStart: analysis]
        )

        viewModel.presentCaptureTimeOffsetSheet()

        XCTAssertTrue(viewModel.isShowingCaptureTimeOffsetSheet)
        XCTAssertEqual(viewModel.selectedCaptureTimeOffset, 9 * 60 * 60)
        XCTAssertTrue(viewModel.captureTimeOffsetNeedsAttention)
        XCTAssertEqual(viewModel.captureTimeOffsetBannerTitle, "Camera Time Zone May Be Wrong")
        XCTAssertEqual(viewModel.captureTimeOffsetCurrentAssumptionLabel, "No shift")
        XCTAssertEqual(viewModel.captureTimeOffsetSuggestedAssumptionLabel, "UTC+09:00")
        XCTAssertEqual(viewModel.captureTimeOffsetButtonTitle, "Preview UTC+09:00")
    }

    func testApplySelectedCaptureTimeOffsetPassesExcludedAssetIDsAndCurrentDay() async {
        let recorder = CaptureTimeOffsetApplyRecorder()
        let firstDayItem = makeReviewItem(
            assetID: "first-day-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_300_000)
        )
        let secondDayItem = makeReviewItem(
            assetID: "second-day-photo",
            coordinate: GeoCoordinate(latitude: 34.6937, longitude: 135.5023),
            label: "Osaka",
            confidence: .maybe,
            disposition: .ambiguous,
            creationDate: Date(timeIntervalSince1970: 1_700_386_400)
        )
        let analysis = makeCaptureTimeOffsetAnalysis(
            assetIDs: [secondDayItem.id],
            recommendedOffset: 9 * 60 * 60
        )
        let secondDayStart = Calendar.autoupdatingCurrent.startOfDay(for: secondDayItem.asset.creationDate)
        let viewModel = makeViewModel(
            items: [firstDayItem, secondDayItem],
            captureTimeOffsetAnalysesByDay: [secondDayStart: analysis],
            onApplyCaptureTimeOffset: { dayStart, offset, excludedAssetIDs in
                await recorder.record(
                    dayStart: dayStart,
                    offset: offset,
                    excludedAssetIDs: excludedAssetIDs
                )
            }
        )

        viewModel.skipForNow(firstDayItem.id)
        viewModel.currentDayIndex = 0
        viewModel.presentCaptureTimeOffsetSheet()
        await viewModel.applySelectedCaptureTimeOffset()

        let snapshot = await recorder.snapshot()
        XCTAssertEqual(snapshot.offset, 9 * 60 * 60)
        XCTAssertEqual(snapshot.excludedAssetIDs, Set([firstDayItem.id]))
        XCTAssertEqual(snapshot.dayStart, secondDayStart)
    }

    func testApplySelectedCaptureTimeOffsetUsesCustomQuarterHourOffset() async {
        let recorder = CaptureTimeOffsetApplyRecorder()
        let item = makeReviewItem(
            assetID: "custom-offset-photo",
            coordinate: GeoCoordinate(latitude: 35.6895, longitude: 139.6917),
            label: "Tokyo",
            confidence: .maybe,
            disposition: .ambiguous
        )
        let dayStart = Calendar.autoupdatingCurrent.startOfDay(for: item.asset.creationDate)
        let analysis = makeCaptureTimeOffsetAnalysis(
            assetIDs: [item.id],
            recommendedOffset: 9 * 60 * 60,
            extraSelectableOffsets: [9.5 * 60 * 60]
        )
        let viewModel = makeViewModel(
            items: [item],
            captureTimeOffsetAnalysesByDay: [dayStart: analysis],
            onApplyCaptureTimeOffset: { dayStart, offset, excludedAssetIDs in
                await recorder.record(
                    dayStart: dayStart,
                    offset: offset,
                    excludedAssetIDs: excludedAssetIDs
                )
            }
        )

        viewModel.presentCaptureTimeOffsetSheet()
        viewModel.selectCaptureTimeOffset(9.5 * 60 * 60)
        await viewModel.applySelectedCaptureTimeOffset()

        let snapshot = await recorder.snapshot()
        XCTAssertEqual(snapshot.dayStart, dayStart)
        XCTAssertEqual(snapshot.offset, 9.5 * 60 * 60)
        XCTAssertEqual(viewModel.captureTimeOffsetSelectedAssumptionLabel, "UTC+09:30")
        XCTAssertFalse(viewModel.selectedCaptureTimeOffsetMatchesSuggestedOption)
    }

    private func makeViewModel(
        items: [ReviewItem],
        dayCaptureTimeOffsets: [Date: TimeInterval] = [:],
        captureTimeOffsetAnalysesByDay: [Date: CaptureTimeOffsetAnalysis] = [:],
        onApplyDecision: @escaping @Sendable (MatchDecision) async throws -> Void = { _ in },
        onDismissPermanently: @escaping @Sendable (ReviewItem) async -> Void = { _ in },
        onUndoAppliedDecisions: @escaping @Sendable ([MatchDecision]) async throws -> Void = { _ in },
        onUndoDismissPermanently: @escaping @Sendable ([String]) async -> Void = { _ in },
        onDeletePhoto: @escaping @Sendable (String) async throws -> Void = { _ in },
        onApplyCaptureTimeOffset: @escaping @Sendable (Date, TimeInterval, Set<String>) async -> Void = { _, _, _ in },
        onCancel: @escaping @Sendable () -> Void = {}
    ) -> ReviewViewModel {
        ReviewViewModel(
            summary: ReviewSummary(
                totalAssets: items.count,
                autoSuggested: items.filter { $0.disposition == .autoSuggested }.count,
                ambiguous: items.filter { $0.disposition == .ambiguous }.count,
                unmatched: 0
            ),
            items: items,
            dayCaptureTimeOffsets: dayCaptureTimeOffsets,
            captureTimeOffsetAnalysesByDay: captureTimeOffsetAnalysesByDay,
            thumbnailProvider: PhotoThumbnailProvider(),
            onApplyDecision: { decision in
                try await onApplyDecision(decision)
            },
            onUndoAppliedDecisions: { decisions in
                try await onUndoAppliedDecisions(decisions)
            },
            onDismissPermanently: { item in
                await onDismissPermanently(item)
            },
            onUndoDismissPermanently: { assetIDs in
                await onUndoDismissPermanently(assetIDs)
            },
            onDeletePhoto: onDeletePhoto,
            onApplyCaptureTimeOffset: onApplyCaptureTimeOffset,
            onCancel: onCancel
        )
    }

    private func makeReviewItem(
        assetID: String,
        coordinate: GeoCoordinate,
        label: String,
        confidence: MatchConfidence,
        disposition: MatchDisposition,
        options: [LocationOption]? = nil,
        selectedPrecision: LocationPrecision = .exact,
        creationDate: Date = Date(timeIntervalSince1970: 1_700_300_000)
    ) -> ReviewItem {
        let asset = PhotoAsset(
            id: assetID,
            creationDate: creationDate,
            hasLocation: false
        )
        let resolvedOptions = options ?? [
            LocationOption(precision: .exact, coordinate: coordinate, label: label)
        ]
        let selectedOption = resolvedOptions.first(where: { $0.precision == selectedPrecision }) ?? resolvedOptions[0]
        let decision = MatchDecision(
            assetID: assetID,
            captureDate: asset.creationDate,
            coordinate: selectedOption.coordinate,
            label: selectedOption.label,
            confidence: confidence,
            precision: selectedOption.precision
        )

        return ReviewItem(
            asset: asset,
            proposedCoordinate: selectedOption.coordinate,
            locationLabel: selectedOption.label,
            confidence: confidence,
            timeDelta: 60,
            disposition: disposition,
            suggestedDecision: decision,
            availableLocationOptions: resolvedOptions
        )
    }

    private func makeCaptureTimeOffsetAnalysis(
        assetIDs: [String],
        currentOffset: TimeInterval = 0,
        recommendedOffset: TimeInterval? = nil,
        extraSelectableOffsets: [TimeInterval] = []
    ) -> CaptureTimeOffsetAnalysis {
        let baseline = makeCaptureTimeOffsetOption(
            offset: currentOffset,
            assetIDs: assetIDs,
            disposition: .unmatched,
            confidence: .rejected,
            timeDelta: 8 * 60 * 60,
            metrics: CaptureTimeOffsetMetrics(
                totalAssets: assetIDs.count,
                autoSuggested: 0,
                ambiguous: 0,
                unmatched: assetIDs.count,
                visitContained: 0,
                medianAbsoluteTimeDelta: 8 * 60 * 60
            )
        )
        let improved = makeCaptureTimeOffsetOption(
            offset: 9 * 60 * 60,
            assetIDs: assetIDs,
            disposition: .autoSuggested,
            confidence: .acceptable,
            timeDelta: 10 * 60,
            metrics: CaptureTimeOffsetMetrics(
                totalAssets: assetIDs.count,
                autoSuggested: assetIDs.count,
                ambiguous: 0,
                unmatched: 0,
                visitContained: assetIDs.count,
                medianAbsoluteTimeDelta: 10 * 60
            )
        )
        let extraOptions = extraSelectableOffsets.map { offset in
            makeCaptureTimeOffsetOption(
                offset: offset,
                assetIDs: assetIDs,
                disposition: .autoSuggested,
                confidence: .acceptable,
                timeDelta: 5 * 60,
                metrics: CaptureTimeOffsetMetrics(
                    totalAssets: assetIDs.count,
                    autoSuggested: assetIDs.count,
                    ambiguous: 0,
                    unmatched: 0,
                    visitContained: assetIDs.count,
                    medianAbsoluteTimeDelta: 5 * 60
                )
            )
        }
        let displayedOptions = recommendedOffset == nil ? [baseline, improved] : [improved, baseline]

        return CaptureTimeOffsetAnalysis(
            currentOffset: currentOffset,
            recommendedOffset: recommendedOffset,
            options: displayedOptions,
            allOptions: displayedOptions + extraOptions
        )
    }

    private func makeCaptureTimeOffsetOption(
        offset: TimeInterval,
        assetIDs: [String],
        disposition: MatchDisposition,
        confidence: MatchConfidence,
        timeDelta: TimeInterval,
        metrics: CaptureTimeOffsetMetrics
    ) -> CaptureTimeOffsetOption {
        let matches = assetIDs.enumerated().map { index, assetID in
            let asset = PhotoAsset(
                id: assetID,
                creationDate: Date(timeIntervalSince1970: 1_700_300_000 + TimeInterval(index * 60)),
                hasLocation: false
            )
            let point = disposition == .unmatched
                ? nil
                : TimelinePoint(
                    id: "point-\(assetID)",
                    timestamp: asset.creationDate.addingTimeInterval(offset),
                    coordinate: GeoCoordinate(latitude: 35 + Double(index), longitude: 139 + Double(index)),
                    source: .visit,
                    semanticLabel: "Preview \(assetID)"
                )
            return MatchCandidate(
                asset: asset,
                point: point,
                timeDelta: disposition == .unmatched ? nil : timeDelta,
                confidence: confidence,
                disposition: disposition
            )
        }

        return CaptureTimeOffsetOption(offset: offset, matches: matches, metrics: metrics)
    }
}

private final class CancellationFlag: @unchecked Sendable {
    var didCancel = false
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

private actor DecisionBatchRecorder {
    private var decisions: [MatchDecision] = []

    func record(_ decisions: [MatchDecision]) {
        self.decisions.append(contentsOf: decisions)
    }

    func recordedAssetIDs() -> [String] {
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

private actor AssetBatchRecorder {
    private var assetIDs: [String] = []

    func record(_ assetIDs: [String]) {
        self.assetIDs.append(contentsOf: assetIDs)
    }

    func snapshot() -> [String] {
        assetIDs
    }
}

private actor CaptureTimeOffsetApplyRecorder {
    private var dayStart: Date?
    private var offset: TimeInterval?
    private var excludedAssetIDs: Set<String> = []

    func record(dayStart: Date, offset: TimeInterval, excludedAssetIDs: Set<String>) {
        self.dayStart = dayStart
        self.offset = offset
        self.excludedAssetIDs = excludedAssetIDs
    }

    func snapshot() -> (dayStart: Date?, offset: TimeInterval?, excludedAssetIDs: Set<String>) {
        (dayStart, offset, excludedAssetIDs)
    }
}
