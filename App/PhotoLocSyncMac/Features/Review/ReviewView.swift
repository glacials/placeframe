import SwiftUI

struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @StateObject private var quickLookController = ReviewQuickLookController()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            dayPager

            if let currentDaySection = viewModel.currentDaySection {
                HSplitView {
                    ReviewGridView(
                        entries: currentDaySection.entries,
                        selectedPhotoIDs: viewModel.selectedPhotoIDs,
                        thumbnailProvider: viewModel.thumbnailProvider,
                        selectPhoto: viewModel.selectPhoto(_:mode:),
                        applyChange: viewModel.applyChange(for:),
                        skipForNow: viewModel.skipForNow(_:),
                        dismissPermanently: viewModel.dismissPermanently(_:),
                        copyLocation: viewModel.copyLocation(for:),
                        pasteLocation: viewModel.pasteLocation(into:),
                        canPasteLocation: viewModel.canPasteLocation(into:),
                        deletePhoto: viewModel.deletePhoto(_:),
                        showOnMap: viewModel.showOnMap(_:),
                        quickLook: { item, sourceView, transitionImage in
                            quickLookController.quickLook(
                                item,
                                using: viewModel.thumbnailProvider,
                                sourceView: sourceView,
                                transitionImage: transitionImage
                            )
                        },
                        captureDateText: viewModel.formattedCaptureDate(for:),
                        timeDeltaText: viewModel.formattedTimeDelta(for:)
                    )
                    .frame(minWidth: 440, idealWidth: 640, maxHeight: .infinity, alignment: .topLeading)

                    ReviewMapView(
                        entries: currentDaySection.entries,
                        selectionTargets: viewModel.mapSelectionTargets
                    )
                        .frame(minWidth: 320, idealWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    viewModel.summary.unmatched > 0 ? "No Timeline Matches" : "No Review Items",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(viewModel.emptyStateDescription)
                )
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .alert(item: $viewModel.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review Proposed Locations")
                .font(.largeTitle.bold())
            Text("Review one day at a time. Nothing is written to Apple Photos until you press Apply on a photo.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryBadge(title: "Photos", value: "\(viewModel.summary.totalAssets)")
                summaryBadge(title: "Auto", value: "\(viewModel.summary.autoSuggested)")
                summaryBadge(title: "Ambiguous", value: "\(viewModel.summary.ambiguous)")
                summaryBadge(title: "No match", value: "\(viewModel.summary.unmatched)")
            }
        }
    }

    private var dayPager: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.goToPreviousDay()
            } label: {
                Label("Previous Day", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canGoToPreviousDay)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentDaySection?.title ?? "No Day Selected")
                    .font(.title3.weight(.semibold))
                Text(viewModel.currentDaySection?.subtitle ?? "0 photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Day \(min(viewModel.currentDayIndex + 1, max(viewModel.daySections.count, 1))) of \(max(viewModel.daySections.count, 1))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.goToNextDay()
            } label: {
                Label("Next Day", systemImage: "chevron.right")
            }
            .disabled(!viewModel.canGoToNextDay)
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                viewModel.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Use each photo's buttons to apply it, skip it for this session, or hide it from future reviews.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
